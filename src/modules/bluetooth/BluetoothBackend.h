#ifndef BLUETOOTHBACKEND_H
#define BLUETOOTHBACKEND_H

#include <QObject>
#include <QProcess>
#include <QSet>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class BluetoothBackend : public QObject
{
    Q_OBJECT

public:
    explicit BluetoothBackend(QObject *parent = nullptr);
    ~BluetoothBackend();

    Q_INVOKABLE QVariantMap getAdapterStatus();
    Q_INVOKABLE void setPower(bool on);
    Q_INVOKABLE QVariantList getPairedDevices();

    Q_INVOKABLE void startScan();
    Q_INVOKABLE void stopScan();

    Q_INVOKABLE void pairAndConnect(const QString &address);
    Q_INVOKABLE void connectDevice(const QString &address);
    Q_INVOKABLE void disconnectDevice(const QString &address);
    Q_INVOKABLE void removeDevice(const QString &address);

signals:
    void scanResult(const QVariantList &devices);
    void pairResult(bool success, const QString &message);
    void connectResult(bool success, const QString &message);
    void disconnectResult(bool success, const QString &message);
    void removeResult(bool success, const QString &message);
    void powerChanged(bool powered);

private slots:
    void pollDiscoveredDevices();
    void onPairFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onConnectFinished(int exitCode, QProcess::ExitStatus exitStatus);

private:
    QString runBtctl(const QStringList &args, int timeoutMs = 5000);
    QVariantMap parseDeviceInfo(const QString &address);
    QSet<QString> getPairedAddresses();

    bool applyAudioRouting();
    void scheduleAudioRouting();
    QString findPactlSink(const QString &pattern);
    void setDefaultSink(const QString &sinkName);

    QProcess *m_scanProc = nullptr;
    QProcess *m_pairProc = nullptr;
    QProcess *m_connectProc = nullptr;
    QTimer *m_scanTimer = nullptr;
    QTimer *m_audioRoutingTimer = nullptr;
    int m_audioRoutingRetries = 0;
    QString m_pairAddress;
    QString m_connectAddress;
    bool m_connectAfterPair = false;
};

#endif
