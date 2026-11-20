#!/bin/bash
set -e
export ANDROID_SDK_ROOT=$HOME/android-sdk
BT=$ANDROID_SDK_ROOT/build-tools/34.0.0
PLATFORM=$ANDROID_SDK_ROOT/platforms/android-34/android.jar
echo "=== 1. 检查JDK ==="
java -version 2>&1 | head -1 || (sudo apt-get install -y -qq openjdk-17-jdk-headless && echo "装了JDK")
echo "=== 2. 下载cmdline-tools ==="
mkdir -p $ANDROID_SDK_ROOT/cmdline-tools
cd /tmp
wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmd.zip
unzip -q cmd.zip -d $ANDROID_SDK_ROOT/cmdline-tools
mv $ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/latest
echo "=== 3. 装platform+build-tools ==="
yes | $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null 2>&1 || true
$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager "platforms;android-34" "build-tools;34.0.0" >/dev/null 2>&1
echo "SDK就绪, android.jar:"; ls -lh $PLATFORM
echo "=== 4. 写App源码 ==="
cd $GITHUB_WORKSPACE
mkdir -p app/src/com/cloud/hello app/res/values
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
import android.widget.*;
import android.view.Gravity;
import android.graphics.Color;
import android.view.View;
public class MainActivity extends Activity {
    int count = 0;
    @Override protected void onCreate(Bundle b){
        super.onCreate(b);
        LinearLayout ll = new LinearLayout(this);
        ll.setOrientation(LinearLayout.VERTICAL);
        ll.setGravity(Gravity.CENTER);
        ll.setBackgroundColor(Color.parseColor("#0a0e1c"));
        TextView tv = new TextView(this);
        tv.setText("云电脑构建的APK");
        tv.setTextColor(Color.parseColor("#7de3b0"));
        tv.setTextSize(24);
        tv.setGravity(Gravity.CENTER);
        TextView num = new TextView(this);
        num.setText("0");
        num.setTextColor(Color.WHITE);
        num.setTextSize(64);
        num.setGravity(Gravity.CENTER);
        Button btn = new Button(this);
        btn.setText("点我 +1");
        btn.setOnClickListener(new View.OnClickListener(){
            public void onClick(View v){ count++; num.setText(String.valueOf(count)); }
        });
        ll.addView(tv);
        ll.addView(num);
        ll.addView(btn);
        setContentView(ll);
    }
}
JAVA
echo "源码写好"
echo "=== 5. aapt2 链接资源+manifest ==="
$BT/aapt2 link -o app.unsigned.apk -I $PLATFORM --manifest app/AndroidManifest.xml --java app/gen
echo "=== 6. javac 编译 ==="
javac -source 8 -target 8 -classpath $PLATFORM -d app/classes app/src/com/cloud/hello/MainActivity.java
echo "生成的class:"; find app/classes -name "*.class"
echo "=== 7. d8 转dex ==="
$BT/d8 --lib $PLATFORM --release --output app/ $(find app/classes -name "*.class")
echo "=== 8. 打包dex进apk ==="
cd app && zip -q ../app.unsigned.apk classes.dex && cd ..
echo "=== 9. zipalign + 签名 ==="
$BT/zipalign -f 4 app.unsigned.apk app.aligned.apk
keytool -genkeypair -keystore debug.keystore -alias k -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=Cloud" >/dev/null 2>&1
$BT/apksigner sign --ks debug.keystore --ks-pass pass:android --key-pass pass:android --out CloudApp.apk app.aligned.apk
echo "=== 10. 完成 ==="
ls -lh CloudApp.apk
echo "签名验证:"; $BT/apksigner verify CloudApp.apk && echo "✅ APK签名有效"
