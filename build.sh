#!/bin/bash
set -e
echo "JDK:"; java -version 2>&1 | head -1
export ANDROID_SDK_ROOT=$HOME/android-sdk
BT=$ANDROID_SDK_ROOT/build-tools/34.0.0
PLATFORM=$ANDROID_SDK_ROOT/platforms/android-34/android.jar
echo "=== 下载SDK ==="
mkdir -p $ANDROID_SDK_ROOT/cmdline-tools
cd /tmp
wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmd.zip
unzip -q cmd.zip -d $ANDROID_SDK_ROOT/cmdline-tools
mv $ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/latest
set +e
yes | $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null 2>&1
set -e
$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager "platforms;android-34" "build-tools;34.0.0" >/dev/null 2>&1
echo "SDK就绪"
cd $GITHUB_WORKSPACE
mkdir -p app/src/com/cloud/hello
cat > app/AndroidManifest.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.cloud.hello">
  <application android:label="CloudApp" android:theme="@android:style/Theme.Material">
    <activity android:name=".MainActivity" android:exported="true">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
XML
cat > app/src/com/cloud/hello/MainActivity.java <<'JAVA'
package com.cloud.hello;
import android.app.Activity;
import android.os.Bundle;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Button;
import android.view.Gravity;
import android.view.View;
import android.graphics.Color;
public class MainActivity extends Activity implements View.OnClickListener {
    private int count = 0;
    private TextView num;
    @Override protected void onCreate(Bundle b){
        super.onCreate(b);
        LinearLayout ll = new LinearLayout(this);
        ll.setOrientation(LinearLayout.VERTICAL);
        ll.setGravity(Gravity.CENTER);
        ll.setBackgroundColor(Color.parseColor("#0a0e1c"));
        TextView tv = new TextView(this);
        tv.setText("Cloud APK");
        tv.setTextColor(Color.parseColor("#7de3b0"));
        tv.setTextSize(24);
        tv.setGravity(Gravity.CENTER);
        num = new TextView(this);
        num.setText("0");
        num.setTextColor(Color.WHITE);
        num.setTextSize(64);
        num.setGravity(Gravity.CENTER);
        Button btn = new Button(this);
        btn.setText("tap +1");
        btn.setOnClickListener(this);
        ll.addView(tv);
        ll.addView(num);
        ll.addView(btn);
        setContentView(ll);
    }
    public void onClick(View v){ count++; num.setText("" + count); }
}
JAVA
echo "源码写好"
echo "=== aapt2 link ==="
$BT/aapt2 link -o app.unsigned.apk -I $PLATFORM --manifest app/AndroidManifest.xml
echo "=== javac (JDK17) ==="
javac -source 8 -target 8 -bootclasspath $PLATFORM -classpath $PLATFORM -d app/classes app/src/com/cloud/hello/MainActivity.java
echo "class:"; find app/classes -name "*.class"
echo "=== d8 ==="
$BT/d8 --lib $PLATFORM --min-api 21 --output app/ $(find app/classes -name "*.class")
echo "dex:"; ls -lh app/classes.dex
echo "=== 打包 ==="
cd app && zip -q ../app.unsigned.apk classes.dex && cd ..
echo "=== 签名 ==="
$BT/zipalign -f 4 app.unsigned.apk app.aligned.apk
keytool -genkeypair -keystore debug.keystore -alias k -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=Cloud" >/dev/null 2>&1
$BT/apksigner sign --ks debug.keystore --ks-pass pass:android --key-pass pass:android --out CloudApp.apk app.aligned.apk
ls -lh CloudApp.apk
$BT/apksigner verify CloudApp.apk && echo "✅签名有效"
