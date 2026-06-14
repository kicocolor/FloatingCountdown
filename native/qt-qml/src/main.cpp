#include <QGuiApplication>
#include <QDateTime>
#include <QFile>
#include <QTextStream>
#include <QQmlApplicationEngine>
#include <QQuickWindow>

static QFile *g_logFile = nullptr;

static void writeLog(const QString &message)
{
    if (!g_logFile || !g_logFile->isOpen()) {
        return;
    }

    QTextStream stream(g_logFile);
    stream << QDateTime::currentDateTime().toString(Qt::ISODate) << " " << message << '\n';
    stream.flush();
}

static void messageHandler(QtMsgType type, const QMessageLogContext &, const QString &message)
{
    const char *level = "info";
    if (type == QtWarningMsg) {
        level = "warning";
    } else if (type == QtCriticalMsg) {
        level = "critical";
    } else if (type == QtFatalMsg) {
        level = "fatal";
    } else if (type == QtDebugMsg) {
        level = "debug";
    }

    writeLog(QStringLiteral("[%1] %2").arg(QString::fromLatin1(level), message));
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QFile logFile(QCoreApplication::applicationDirPath() + QStringLiteral("/floating-countdown-qt.log"));
    if (logFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        g_logFile = &logFile;
        qInstallMessageHandler(messageHandler);
        writeLog(QStringLiteral("FloatingCountdown starting"));
    }

    QGuiApplication::setOrganizationName(QStringLiteral("kicocolor"));
    QGuiApplication::setApplicationName(QStringLiteral("FloatingCountdown"));

    QQuickWindow::setDefaultAlphaBuffer(true);

    QQmlApplicationEngine engine;
    const QUrl url(QStringLiteral("FloatingCountdown/Main"));
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, &app, [](const QList<QQmlError> &warnings) {
        for (const QQmlError &warning : warnings) {
            writeLog(QStringLiteral("QML warning: %1").arg(warning.toString()));
        }
    });
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() {
            writeLog(QStringLiteral("QML object creation failed"));
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("FloatingCountdown"), QStringLiteral("Main"));
    writeLog(QStringLiteral("QML load requested"));

    const int result = app.exec();
    writeLog(QStringLiteral("FloatingCountdown exited with %1").arg(result));
    return result;
}
