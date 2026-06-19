#include "NetworkBackend.h"
#include <QDebug>

NetworkBackend::NetworkBackend(QObject *parent)
    : QObject(parent)
{
}

QString NetworkBackend::runNmcli(const QStringList &args)
{
    QProcess proc;
    proc.setProgram("nmcli");
    proc.setArguments(args);
    proc.start();
    proc.waitForFinished(10000);
    return proc.readAllStandardOutput().trimmed();
}

QString NetworkBackend::findWifiDevice()
{
    QString out = runNmcli({"--terse", "--fields", "DEVICE,TYPE", "device"});
    for (const QString &line : out.split('\n')) {
        QStringList parts = line.split(':');
        if (parts.size() >= 2 && parts[1] == "wifi")
            return parts[0];
    }
    return {};
}

QString NetworkBackend::findEthernetDevice()
{
    QString out = runNmcli({"--terse", "--fields", "DEVICE,TYPE", "device"});
    for (const QString &line : out.split('\n')) {
        QStringList parts = line.split(':');
        if (parts.size() >= 2 && parts[1] == "ethernet")
            return parts[0];
    }
    return {};
}

QVariantList NetworkBackend::parseScanOutput(const QString &output)
{
    QVariantList networks;
    QStringList seen;
    for (const QString &line : output.split('\n')) {
        if (line.trimmed().isEmpty()) continue;

        QStringList parts = line.split(':');
        if (parts.size() < 4) continue;

        QString ssid = parts[0].trimmed();
        if (ssid.isEmpty() || seen.contains(ssid)) continue;
        seen.append(ssid);

        QVariantMap net;
        net["ssid"]     = ssid;
        net["signal"]   = parts[1].toInt();
        net["security"] = parts[2].trimmed();
        net["active"]   = parts[3].trimmed() == "*";
        networks.append(net);
    }
    return networks;
}

void NetworkBackend::cancelScan()
{
    if (m_scanDelayTimer) {
        m_scanDelayTimer->stop();
        delete m_scanDelayTimer;
        m_scanDelayTimer = nullptr;
    }
    if (m_scanProc) {
        m_scanProc->kill();
        m_scanProc->waitForFinished(2000);
        m_scanProc->deleteLater();
        m_scanProc = nullptr;
    }
}

void NetworkBackend::scanWifi()
{
    cancelScan();

    m_scanDev = findWifiDevice();
    if (m_scanDev.isEmpty()) {
        emit wifiScanComplete({});
        return;
    }

    m_scanProc = new QProcess(this);
    connect(m_scanProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &NetworkBackend::onRescanFinished);
    m_scanProc->setProgram("nmcli");
    m_scanProc->setArguments({"device", "wifi", "rescan", "ifname", m_scanDev});
    m_scanProc->start();
}

void NetworkBackend::onRescanFinished(int, QProcess::ExitStatus)
{
    if (!m_scanProc) return;
    m_scanProc->deleteLater();
    m_scanProc = nullptr;

    m_scanDelayTimer = new QTimer(this);
    m_scanDelayTimer->setSingleShot(true);
    connect(m_scanDelayTimer, &QTimer::timeout, this, &NetworkBackend::fetchWifiList);
    m_scanDelayTimer->start(3000);
}

void NetworkBackend::fetchWifiList()
{
    if (m_scanDelayTimer) {
        delete m_scanDelayTimer;
        m_scanDelayTimer = nullptr;
    }

    m_scanProc = new QProcess(this);
    connect(m_scanProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &NetworkBackend::onScanFinished);
    m_scanProc->setProgram("nmcli");
    m_scanProc->setArguments({"--terse", "--fields", "SSID,SIGNAL,SECURITY,IN-USE",
                              "device", "wifi", "list", "--rescan", "no",
                              "ifname", m_scanDev});
    m_scanProc->start();
}

void NetworkBackend::onScanFinished(int, QProcess::ExitStatus)
{
    if (!m_scanProc) return;

    QString out = m_scanProc->readAllStandardOutput().trimmed();
    m_scanProc->deleteLater();
    m_scanProc = nullptr;

    emit wifiScanComplete(parseScanOutput(out));
}

void NetworkBackend::connectWifi(const QString &ssid, const QString &password, const QString &security)
{
    if (m_connectProc) {
        m_connectProc->kill();
        m_connectProc->waitForFinished(2000);
        m_connectProc->deleteLater();
        m_connectProc = nullptr;
    }

    // Remove any stale profile so we don't accumulate duplicates
    QProcess del;
    del.setProgram("nmcli");
    del.setArguments({"connection", "delete", "id", ssid});
    del.start();
    del.waitForFinished(5000);

    QString dev = findWifiDevice();
    if (dev.isEmpty()) {
        emit wifiConnectResult(false, "No WiFi device found");
        return;
    }

    QString keyMgmt = "wpa-psk";
    if (security.contains("SAE") || security.contains("WPA3"))
        keyMgmt = "sae";

    QProcess add;
    add.setProgram("nmcli");
    add.setArguments({"connection", "add",
                      "type", "wifi",
                      "ifname", dev,
                      "con-name", ssid,
                      "ssid", ssid,
                      "wifi-sec.key-mgmt", keyMgmt,
                      "wifi-sec.psk", password,
                      "connection.autoconnect", "yes",
                      "connection.autoconnect-priority", "10"});
    add.start();
    add.waitForFinished(5000);

    if (add.exitCode() != 0) {
        QString err = add.readAllStandardError().trimmed();
        emit wifiConnectResult(false, err.isEmpty() ? "Failed to create profile" : err);
        return;
    }

    m_connectSsid = ssid;
    m_connectProc = new QProcess(this);
    connect(m_connectProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &NetworkBackend::onConnectFinished);
    m_connectProc->setProgram("nmcli");
    m_connectProc->setArguments({"connection", "up", "id", ssid});
    m_connectProc->start();
}

void NetworkBackend::connectOpenWifi(const QString &ssid)
{
    if (m_connectProc) {
        m_connectProc->kill();
        m_connectProc->waitForFinished(2000);
        m_connectProc->deleteLater();
        m_connectProc = nullptr;
    }

    QProcess del;
    del.setProgram("nmcli");
    del.setArguments({"connection", "delete", "id", ssid});
    del.start();
    del.waitForFinished(5000);

    QString dev = findWifiDevice();
    if (dev.isEmpty()) {
        emit wifiConnectResult(false, "No WiFi device found");
        return;
    }

    QProcess add;
    add.setProgram("nmcli");
    add.setArguments({"connection", "add",
                      "type", "wifi",
                      "ifname", dev,
                      "con-name", ssid,
                      "ssid", ssid,
                      "connection.autoconnect", "yes",
                      "connection.autoconnect-priority", "10"});
    add.start();
    add.waitForFinished(5000);

    if (add.exitCode() != 0) {
        QString err = add.readAllStandardError().trimmed();
        emit wifiConnectResult(false, err.isEmpty() ? "Failed to create profile" : err);
        return;
    }

    m_connectSsid = ssid;
    m_connectProc = new QProcess(this);
    connect(m_connectProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &NetworkBackend::onConnectFinished);
    m_connectProc->setProgram("nmcli");
    m_connectProc->setArguments({"connection", "up", "id", ssid});
    m_connectProc->start();
}

void NetworkBackend::onConnectFinished(int exitCode, QProcess::ExitStatus)
{
    if (!m_connectProc) return;

    QString output = m_connectProc->readAllStandardOutput().trimmed();
    QString errOutput = m_connectProc->readAllStandardError().trimmed();
    m_connectProc->deleteLater();
    m_connectProc = nullptr;

    if (exitCode == 0) {
        emit wifiConnectResult(true, "Connected to " + m_connectSsid);
    } else {
        QString msg = errOutput.isEmpty() ? output : errOutput;
        if (msg.contains("Secrets were required"))
            msg = "Incorrect password";
        emit wifiConnectResult(false, msg);
    }
}

void NetworkBackend::disconnectWifi()
{
    QString dev = findWifiDevice();
    if (!dev.isEmpty())
        runNmcli({"device", "disconnect", dev});
}

void NetworkBackend::forgetWifi(const QString &ssid)
{
    QProcess proc;
    proc.setProgram("nmcli");
    proc.setArguments({"connection", "delete", "id", ssid});
    proc.start();
    proc.waitForFinished(10000);

    bool ok = proc.exitCode() == 0;
    QString err = proc.readAllStandardError().trimmed();
    emit wifiForgetResult(ok, ok ? "Forgot " + ssid : (err.isEmpty() ? "No saved profile for " + ssid : err));
}

QVariantMap NetworkBackend::getWifiStatus()
{
    QVariantMap result;
    QString dev = findWifiDevice();
    result["available"] = !dev.isEmpty();
    if (dev.isEmpty()) return result;

    QString out = runNmcli({"--terse", "--fields", "DEVICE,STATE,CONNECTION", "device", "status"});
    for (const QString &line : out.split('\n')) {
        QStringList parts = line.split(':');
        if (parts.size() >= 3 && parts[0] == dev) {
            result["state"] = parts[1];
            result["connection"] = parts[2];
            break;
        }
    }

    QString ipOut = runNmcli({"--terse", "--fields", "IP4.ADDRESS", "device", "show", dev});
    for (const QString &line : ipOut.split('\n')) {
        if (line.contains("IP4.ADDRESS")) {
            QString ip = line.split(':').last().trimmed();
            if (ip.contains('/')) ip = ip.split('/').first();
            result["ip"] = ip;
            break;
        }
    }

    return result;
}

QVariantMap NetworkBackend::getEthernetStatus()
{
    QVariantMap result;
    QString dev = findEthernetDevice();
    result["available"] = !dev.isEmpty();
    if (dev.isEmpty()) return result;

    QString out = runNmcli({"--terse", "--fields", "DEVICE,STATE,CONNECTION", "device", "status"});
    for (const QString &line : out.split('\n')) {
        QStringList parts = line.split(':');
        if (parts.size() >= 3 && parts[0] == dev) {
            result["state"] = parts[1];
            result["connection"] = parts[2];
            break;
        }
    }

    QString ipOut = runNmcli({"--terse", "--fields", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "device", "show", dev});
    for (const QString &line : ipOut.split('\n')) {
        if (line.contains("IP4.ADDRESS")) {
            QString ip = line.split(':').last().trimmed();
            result["ip"] = ip;
        } else if (line.contains("IP4.GATEWAY")) {
            result["gateway"] = line.split(':').last().trimmed();
        } else if (line.contains("IP4.DNS")) {
            result["dns"] = line.split(':').last().trimmed();
        }
    }

    QString connName = result.value("connection").toString();
    if (!connName.isEmpty()) {
        QString methodOut = runNmcli({"--terse", "--fields", "ipv4.method", "connection", "show", connName});
        result["method"] = methodOut.split(':').last().trimmed();
    }

    return result;
}

void NetworkBackend::setEthernetDhcp()
{
    QString dev = findEthernetDevice();
    if (dev.isEmpty()) {
        emit ethernetConfigResult(false, "No ethernet device found");
        return;
    }

    QString connOut = runNmcli({"--terse", "--fields", "NAME,DEVICE", "connection", "show", "--active"});
    QString connName;
    for (const QString &line : connOut.split('\n')) {
        QStringList parts = line.split(':');
        if (parts.size() >= 2 && parts[1] == dev) {
            connName = parts[0];
            break;
        }
    }

    if (connName.isEmpty()) connName = "Wired connection 1";

    runNmcli({"connection", "modify", connName,
              "ipv4.method", "auto",
              "ipv4.addresses", "", "ipv4.gateway", "", "ipv4.dns", "",
              "connection.autoconnect", "yes",
              "connection.autoconnect-priority", "100"});
    runNmcli({"connection", "up", connName});

    emit ethernetConfigResult(true, "Ethernet set to DHCP");
}

void NetworkBackend::setEthernetStatic(const QString &ip, const QString &gateway, const QString &dns)
{
    QString dev = findEthernetDevice();
    if (dev.isEmpty()) {
        emit ethernetConfigResult(false, "No ethernet device found");
        return;
    }

    QString addr = ip.contains('/') ? ip : ip + "/24";

    QString connOut = runNmcli({"--terse", "--fields", "NAME,DEVICE", "connection", "show", "--active"});
    QString connName;
    for (const QString &line : connOut.split('\n')) {
        QStringList parts = line.split(':');
        if (parts.size() >= 2 && parts[1] == dev) {
            connName = parts[0];
            break;
        }
    }

    if (connName.isEmpty()) connName = "Wired connection 1";

    QStringList modifyArgs = {"connection", "modify", connName,
                              "ipv4.method", "manual",
                              "ipv4.addresses", addr,
                              "ipv4.gateway", gateway,
                              "connection.autoconnect", "yes",
                              "connection.autoconnect-priority", "100"};
    if (!dns.isEmpty())
        modifyArgs << "ipv4.dns" << dns;

    runNmcli(modifyArgs);
    runNmcli({"connection", "up", connName});

    emit ethernetConfigResult(true, "Static IP configured");
}

QVariantMap NetworkBackend::getActiveConnection()
{
    QVariantMap result;

    QVariantMap wifi = getWifiStatus();
    if (wifi.value("state").toString() == "connected") {
        result["type"] = "wifi";
        result["name"] = wifi.value("connection");
        result["ip"]   = wifi.value("ip");
        return result;
    }

    QVariantMap eth = getEthernetStatus();
    if (eth.value("state").toString() == "connected") {
        result["type"] = "ethernet";
        result["name"] = eth.value("connection");
        result["ip"]   = eth.value("ip");
        return result;
    }

    result["type"] = "none";
    return result;
}
