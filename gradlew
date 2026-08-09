#!/bin/sh

# اسکریپت اجرای Gradle Wrapper برای سیستم‌های POSIX.

APP_NAME="Gradle"
APP_BASE_NAME=$(basename "$0")

warn() {
    echo "$*" >&2
}

die() {
    echo >&2
    echo "$*" >&2
    echo >&2
    exit 1
}

# مسیر مطلق ریشه پروژه را پیدا می‌کند.
APP_HOME=$(CDPATH= cd "$(dirname "$0")" >/dev/null 2>&1 && pwd -P) ||
    die "خطا: مسیر پروژه قابل تشخیص نیست."

CLASSPATH="$APP_HOME/gradle/wrapper/gradle-wrapper.jar"

# دستور Java را از JAVA_HOME یا PATH پیدا می‌کند.
if [ -n "$JAVA_HOME" ]; then
    if [ -x "$JAVA_HOME/jre/sh/java" ]; then
        JAVACMD="$JAVA_HOME/jre/sh/java"
    else
        JAVACMD="$JAVA_HOME/bin/java"
    fi
    [ -x "$JAVACMD" ] || die "خطا: JAVA_HOME معتبر نیست: $JAVA_HOME"
else
    JAVACMD=$(command -v java 2>/dev/null)
    [ -n "$JAVACMD" ] || die "خطا: JDK 17 نصب نیست یا دستور java در PATH پیدا نشد."
fi

exec "$JAVACMD" \
    -Xmx64m \
    -Xms64m \
    $JAVA_OPTS \
    $GRADLE_OPTS \
    "-Dorg.gradle.appname=$APP_BASE_NAME" \
    -classpath "$CLASSPATH" \
    org.gradle.wrapper.GradleWrapperMain \
    "$@"
