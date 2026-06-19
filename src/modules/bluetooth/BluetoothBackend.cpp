#include "BluetoothBackend.h"
#include <QDebug>

BluetoothBackend::BluetoothBackend(QObject *parent)
    : QObject(parent)
{
    QTimer::singleShot(2000, this, [this] { applyAudioRouting(); });
}

BluetoothBackend::~BluetoothBackend()
{
    stopScan();
}

QString BluetoothBackend::runBtctl(const QStringList &args, int timeoutMs)
{
    QProcess proc;
    proc.setProgram("bluetoothctl");
    proc.setArguments(args);
    proc.start();
    proc.waitForFinished(timeoutMs);
    return proc.readAllStandardOutput().trimmed();
}

QVariantMap BluetoothBackend::parseDeviceInfo(const QString &address)
{
    QVariantMap info;
    QString out = runBtctl({"info", address});

    for (const QString &line : out.split('\n')) {
        QString trimmed = line.trimmed();
        if (trimmed.startsWith("Connected:"))
            info["connected"] = trimmed.endsWith("yes");
        else if (trimmed.startsWith("Paired:"))
            info["paired"] = trimmed.endsWith("yes");
        else if (trimmed.startsWith("Trusted:"))
            info["trusted"] = trimmed.endsWith("yes");
        else if (trimmed.startsWith("Icon:"))
            info["icon"] = trimmed.mid(5).trimmed();
        else if (trimmed.startsWith("Name:"))
            info["name"] = trimmed.mid(5).trimmed();
    }

    return info;
}

QSet<QString> BluetoothBackend::getPairedAddresses()
{
    QSet<QString> addrs;
    QString out = runBtctl({"devices", "Paired"});
    for (const QString &line : out.split('\n')) {
        if (!line.startsWith("Device ")) continue;
        QString rest = line.mid(7);
        int sp = rest.indexOf(' ');
        if (sp > 0) addrs.insert(rest.left(sp));
    }
    return addrs;
}

// ── Adapter ──────────────────────────────────────────────────────────────────

QVariantMap BluetoothBackend::getAdapterStatus()
{
    QVariantMap result;
    QString out = runBtctl({"show"});

    result["available"] = !out.isEmpty() && !out.contains("No default controller");
    result["powered"]   = out.contains("Powered: yes");

    QVariantList paired = getPairedDevices();
    int connected = 0;
    QString connName;
    for (const auto &v : paired) {
        QVariantMap dev = v.toMap();
        if (dev["connected"].toBool()) {
            connected++;
            if (connName.isEmpty()) connName = dev["name"].toString();
        }
    }
    result["connectedCount"] = connected;
    result["connectedName"]  = connName;

    return result;
}

void BluetoothBackend::setPower(bool on)
{
    runBtctl({"power", on ? "on" : "off"});
    emit powerChanged(on);
}

// ── Paired devices ───────────────────────────────────────────────────────────

QVariantList BluetoothBackend::getPairedDevices()
{
    QString out = runBtctl({"devices", "Paired"});
    QVariantList devices;

    for (const QString &line : out.split('\n')) {
        if (!line.startsWith("Device ")) continue;

        QString rest = line.mid(7);
        int sp = rest.indexOf(' ');
        if (sp < 0) continue;

        QString address = rest.left(sp);
        QString name    = rest.mid(sp + 1).trimmed();

        QVariantMap info = parseDeviceInfo(address);
        QVariantMap dev;
        dev["address"]   = address;
        dev["name"]      = name.isEmpty() ? address : name;
        dev["connected"] = info.value("connected", false);
        dev["icon"]      = info.value("icon", "");
        devices.append(dev);
    }

    return devices;
}

// ── Scanning ─────────────────────────────────────────────────────────────────

void BluetoothBackend::startScan()
{
    stopScan();

    runBtctl({"power", "on"});
    runBtctl({"pairable", "on"});
    runBtctl({"discoverable", "on"});

    // bluetoothctl scan on exits immediately without a tty, which kills the
    // D-Bus discovery session.  Running bluetoothctl in interactive mode and
    // piping "scan on" via stdin keeps the process (and the scan) alive.
    m_scanProc = new QProcess(this);
    m_scanProc->setProgram("bluetoothctl");
    m_scanProc->start();
    m_scanProc->waitForStarted(2000);
    m_scanProc->write("scan on\n");

    if (!m_scanTimer) {
        m_scanTimer = new QTimer(this);
        connect(m_scanTimer, &QTimer::timeout,
                this, &BluetoothBackend::pollDiscoveredDevices);
    }
    m_scanTimer->start(2000);

    QTimer::singleShot(1500, this, &BluetoothBackend::pollDiscoveredDevices);
}

void BluetoothBackend::stopScan()
{
    if (m_scanTimer) m_scanTimer->stop();

    if (m_scanProc) {
        m_scanProc->write("scan off\n");
        m_scanProc->write("exit\n");
        m_scanProc->waitForFinished(2000);
        m_scanProc->kill();
        m_scanProc->waitForFinished(1000);
        m_scanProc->deleteLater();
        m_scanProc = nullptr;
    }

    runBtctl({"discoverable", "off"});
}

void BluetoothBackend::pollDiscoveredDevices()
{
    QString out = runBtctl({"devices"});
    QSet<QString> pairedAddrs = getPairedAddresses();
    QVariantList devices;

    for (const QString &line : out.split('\n')) {
        if (!line.startsWith("Device ")) continue;

        QString rest = line.mid(7);
        int sp = rest.indexOf(' ');
        if (sp < 0) continue;

        QString address = rest.left(sp);
        QString name    = rest.mid(sp + 1).trimmed();

        if (pairedAddrs.contains(address)) continue;
        if (name.isEmpty() || name == address) continue;

        QVariantMap dev;
        dev["address"] = address;
        dev["name"]    = name;
        devices.append(dev);
    }

    emit scanResult(devices);
}

// ── Pair / connect / disconnect / remove ─────────────────────────────────────

void BluetoothBackend::pairAndConnect(const QString &address)
{
    if (m_pairProc) {
        m_pairProc->kill();
        m_pairProc->waitForFinished(2000);
        m_pairProc->deleteLater();
        m_pairProc = nullptr;
    }

    m_pairAddress = address;
    m_pairProc = new QProcess(this);
    connect(m_pairProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &BluetoothBackend::onPairFinished);
    m_pairProc->setProgram("bluetoothctl");
    m_pairProc->setArguments({"pair", address});
    m_pairProc->start();
}

void BluetoothBackend::onPairFinished(int exitCode, QProcess::ExitStatus)
{
    if (!m_pairProc) return;

    QString out = m_pairProc->readAllStandardOutput().trimmed();
    QString err = m_pairProc->readAllStandardError().trimmed();
    m_pairProc->deleteLater();
    m_pairProc = nullptr;

    bool success = exitCode == 0
                || out.contains("Pairing successful")
                || out.contains("AlreadyExists");

    if (success) {
        runBtctl({"trust", m_pairAddress});
        m_connectAfterPair = true;
        connectDevice(m_pairAddress);
        emit pairResult(true, "Paired successfully");
    } else {
        QString msg = err.isEmpty() ? out : err;
        if (msg.isEmpty()) msg = "Pairing failed";
        emit pairResult(false, msg);
    }
}

void BluetoothBackend::connectDevice(const QString &address)
{
    if (m_connectProc) {
        m_connectProc->kill();
        m_connectProc->waitForFinished(2000);
        m_connectProc->deleteLater();
        m_connectProc = nullptr;
    }

    m_connectAddress = address;
    m_connectProc = new QProcess(this);
    connect(m_connectProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &BluetoothBackend::onConnectFinished);
    m_connectProc->setProgram("bluetoothctl");
    m_connectProc->setArguments({"connect", address});
    m_connectProc->start();
}

void BluetoothBackend::onConnectFinished(int exitCode, QProcess::ExitStatus)
{
    if (!m_connectProc) return;

    QString out = m_connectProc->readAllStandardOutput().trimmed();
    QString err = m_connectProc->readAllStandardError().trimmed();
    m_connectProc->deleteLater();
    m_connectProc = nullptr;

    bool success = exitCode == 0 || out.contains("Connection successful");

    bool wasAfterPair = m_connectAfterPair;
    m_connectAfterPair = false;

    if (success) {
        scheduleAudioRouting();
        emit connectResult(true, "Connected");
    } else {
        if (wasAfterPair)
            runBtctl({"remove", m_connectAddress});
        QString msg = err.isEmpty() ? out : err;
        if (msg.isEmpty()) msg = "Connection failed";
        emit connectResult(false, msg);
    }
}

void BluetoothBackend::disconnectDevice(const QString &address)
{
    QString out = runBtctl({"disconnect", address});
    bool ok = out.contains("Successful") || out.contains("disconnected");
    if (ok)
        QTimer::singleShot(2000, this, [this] { applyAudioRouting(); });
    emit disconnectResult(ok, ok ? "Disconnected" : "Disconnect failed");
}

void BluetoothBackend::removeDevice(const QString &address)
{
    runBtctl({"disconnect", address});
    QString out = runBtctl({"remove", address});
    bool ok = out.contains("removed") || out.contains("not available");
    if (ok)
        QTimer::singleShot(2000, this, [this] { applyAudioRouting(); });
    emit removeResult(ok, ok ? "Device removed" : "Remove failed");
}

// ── Audio routing ───────────────────────────────────────────────────────────

bool BluetoothBackend::applyAudioRouting()
{
    QString btSink = findPactlSink("bluez");
    if (!btSink.isEmpty()) {
        setDefaultSink(btSink);
        qInfo("[BluetoothBackend] Audio → Bluetooth: %s", qPrintable(btSink));
        return true;
    }

    QString hdmiSink = findPactlSink("hdmi");
    if (!hdmiSink.isEmpty()) {
        setDefaultSink(hdmiSink);
        qInfo("[BluetoothBackend] Audio → HDMI: %s", qPrintable(hdmiSink));
    }
    return false;
}

void BluetoothBackend::scheduleAudioRouting()
{
    m_audioRoutingRetries = 0;
    if (!m_audioRoutingTimer) {
        m_audioRoutingTimer = new QTimer(this);
        m_audioRoutingTimer->setInterval(1500);
        connect(m_audioRoutingTimer, &QTimer::timeout, this, [this] {
            if (applyAudioRouting() || ++m_audioRoutingRetries >= 4)
                m_audioRoutingTimer->stop();
        });
    }
    m_audioRoutingTimer->start();
}

QString BluetoothBackend::findPactlSink(const QString &pattern)
{
    QProcess proc;
    proc.setProgram("pactl");
    proc.setArguments({"list", "sinks", "short"});
    proc.start();
    if (!proc.waitForFinished(3000)) return {};

    const QString output = proc.readAllStandardOutput();
    for (const QString &line : output.split('\n')) {
        const QStringList fields = line.split('\t');
        if (fields.size() >= 2 && fields[1].contains(pattern, Qt::CaseInsensitive))
            return fields[1];
    }
    return {};
}

void BluetoothBackend::setDefaultSink(const QString &sinkName)
{
    QProcess proc;
    proc.setProgram("pactl");
    proc.setArguments({"set-default-sink", sinkName});
    proc.start();
    proc.waitForFinished(3000);
}
