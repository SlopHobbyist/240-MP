#ifndef NETWORKBACKEND_H
#define NETWORKBACKEND_H

#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class NetworkBackend : public QObject
{
    Q_OBJECT

public:
    explicit NetworkBackend(QObject *parent = nullptr);

    Q_INVOKABLE void scanWifi();
    Q_INVOKABLE void connectWifi(const QString &ssid, const QString &password, const QString &security);
    Q_INVOKABLE void connectOpenWifi(const QString &ssid);
    Q_INVOKABLE void disconnectWifi();
    Q_INVOKABLE void forgetWifi(const QString &ssid);
    Q_INVOKABLE QVariantMap getWifiStatus();

    Q_INVOKABLE QVariantMap getEthernetStatus();
    Q_INVOKABLE void setEthernetDhcp();
    Q_INVOKABLE void setEthernetStatic(const QString &ip, const QString &gateway, const QString &dns);

    Q_INVOKABLE QVariantMap getActiveConnection();

signals:
    void wifiScanComplete(const QVariantList &networks);
    void wifiConnectResult(bool success, const QString &message);
    void wifiForgetResult(bool success, const QString &message);
    void ethernetConfigResult(bool success, const QString &message);
    void statusReady(const QVariantMap &status);

private slots:
    void onRescanFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onScanFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onConnectFinished(int exitCode, QProcess::ExitStatus exitStatus);

private:
    void fetchWifiList();
    void cancelScan();
    QString runNmcli(const QStringList &args);
    QString findEthernetDevice();
    QString findWifiDevice();
    QVariantList parseScanOutput(const QString &output);

    QProcess *m_scanProc = nullptr;
    QProcess *m_connectProc = nullptr;
    QTimer   *m_scanDelayTimer = nullptr;
    QString   m_scanDev;
    QString   m_connectSsid;
};

#endif
