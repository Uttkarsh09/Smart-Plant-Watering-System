#if defined(ESP32)
#include <WiFi.h>
#elif defined(ESP8266)
#include <ESP8266WiFi.h>
#endif
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>
#include <SimpleTimer.h>
#include <DHT.h>

#define WIFI_SSID "ssid"
#define WIFI_PASSWORD "password"
#define API_KEY "firebase_api_key"
#define DATABASE_URL "realtime_db_url" //<databaseName>.firebaseio.com or <databaseName>.<region>.firebasedatabase.app
#define USER_EMAIL "firebase_authenticated_email"
#define USER_PASSWORD "firebase_authenticated_password"
#define TEMPORARY_LED D2
#define DHT11_PIN D4 // GPIO2 = D4
#define DHT11_TYPE DHT11
#define SOIL_MOISTURE_PIN 0 // Here 0 is for A0 analog0
#define WATER_PUMP_PIN D1
#define PUMP_SUPPLIMENT_1 D8
#define PUMP_SUPPLIMENT_2 D5
#define SOIL_MOISTURE_THRESHOLD 30

// Define Firebase Data object
FirebaseData fbdo;
FirebaseData tempPinFBDO; // Firebase data object to check tempPin Status
FirebaseData isWateringFBDO;
FirebaseAuth auth;
FirebaseConfig config;
SimpleTimer simpleTimer;
SimpleTimer isWateringTimer;
SimpleTimer checkTemporaryPinTimer;
DHT dht(DHT11_PIN, DHT11_TYPE);

unsigned long sendDataPrevMillis = 0;
unsigned long count = 0;
float temperature = 0;
int humidity = 0;
int soilMoisture = 0;
boolean isWatering = false;

void setup()
{
	Serial.begin(115200);
	WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
	Serial.print("Connecting to Wi-Fi");
	while (WiFi.status() != WL_CONNECTED)
	{
		Serial.print(".");
		delay(300);
	}
	Serial.print("\nConnected with IP: ");
	Serial.println(WiFi.localIP());
	Serial.println();
	Serial.printf("Firebase Client v%s\n\n", FIREBASE_CLIENT_VERSION);

	config.api_key = API_KEY;
	auth.user.email = USER_EMAIL;
	auth.user.password = USER_PASSWORD;
	config.database_url = DATABASE_URL;
	/* Assign the callback function for the long running token generation task */
	config.token_status_callback = tokenStatusCallback; // see addons/TokenHelper.h
	Firebase.begin(&config, &auth);
	Firebase.reconnectWiFi(true); // Comment or pass false value when WiFi reconnection will control by your code or third party library
	Firebase.setDoubleDigits(5);

	pinMode(TEMPORARY_LED, OUTPUT);
	pinMode(WATER_PUMP_PIN, OUTPUT);
	pinMode(PUMP_SUPPLIMENT_1, OUTPUT);
	pinMode(PUMP_SUPPLIMENT_2, OUTPUT);

	dht.begin();

	config.timeout.serverResponse = 10 * 1000;
	simpleTimer.setInterval(1000);
	isWateringTimer.setInterval(1000);
	checkTemporaryPinTimer.setInterval(3000);
}

void loop()
{
	if (simpleTimer.isReady())
	{
		readSensorData();
		simpleTimer.reset();
	}

	if (isWateringTimer.isReady())
	{
		Firebase.RTDB.getBool(&isWateringFBDO, F("/isWatering"));
		isWatering = isWateringFBDO.to<bool>();
		if (isWatering)
		{
			Serial.println("WATERING");
			startMotor();
		}
		else
		{
			Serial.println("NOT WATERING");
			stopMotor();
		}

		isWateringTimer.reset();
	}

	if (checkTemporaryPinTimer.isReady())
	{
		Firebase.RTDB.getBool(&tempPinFBDO, F("/tempLED"));
		// tempPinFBDO.to<bool>() ? Serial.println("TEMP PIN SET") : Serial.println("TEMP PIN NOT SET");
		tempPinFBDO.to<bool>() ? digitalWrite(TEMPORARY_LED, HIGH) : digitalWrite(TEMPORARY_LED, LOW);
		// Serial.printf("Get bool... %s\n", Firebase.RTDB.getBool(&fbdo, FPSTR("tempLED")) ? (fbdo.to<bool>() ? "true" : "false") : fbdo.errorReason().c_str());
		checkTemporaryPinTimer.reset();
	}
}

void readSensorData()
{
	float temperature = dht.readTemperature();
	humidity = dht.readHumidity();
	float tempReading = 0.0;
	tempReading = analogRead(SOIL_MOISTURE_PIN);
	tempReading /= 1023;
	tempReading = 100 - (tempReading * 100);
	if (tempReading < 0)
		tempReading = 0;
	soilMoisture = tempReading;
	Serial.printf("Temperature %f \tHumidity %d \tSoilMoisture %d\n", temperature, humidity, soilMoisture);

	boolean temperaturUpdate = Firebase.RTDB.setFloat(&fbdo, F("/currentTemperature"), temperature);
	boolean humidityUpdate = Firebase.RTDB.setInt(&fbdo, F("/currentHumidity"), humidity);
	boolean moistureUpdate = Firebase.RTDB.setInt(&fbdo, F("/currentSoilMoisture"), soilMoisture);

	temperaturUpdate ? Serial.print("") : Serial.println("ERROR WHILE Updating Temperature");
	humidityUpdate ? Serial.print("") : Serial.println("ERROR WHILE Updating Humidity");
	moistureUpdate ? Serial.print("") : Serial.println("ERROR WHILE Updating Moisture");

	if (soilMoisture < SOIL_MOISTURE_THRESHOLD)
	{
		startWatering();
	}
}

void startWatering()
{
	isWatering = true;
	while (soilMoisture < SOIL_MOISTURE_THRESHOLD)
	{
		startMotor();
		soilMoisture = analogRead(SOIL_MOISTURE_PIN);
		soilMoisture /= 1023;
		soilMoisture = 100 - (soilMoisture * 100);
		if (soilMoisture < 0)
			soilMoisture = 0;
		bool isWateringUpdated = Firebase.RTDB.setBool(&fbdo, F("/isWatering"), true);
		isWateringUpdated ? Serial.println("1 - IS_WATERING Updated") : Serial.println("ERROR WHILE Updating IS_WATERING");
		delay(1000);
	}
	stopMotor();
	bool isWateringUpdated = Firebase.RTDB.setBool(&fbdo, F("/isWatering"), false);
	isWateringUpdated ? Serial.println("~~ 2 - IS_WATERING Updated") : Serial.println("ERROR WHILE Updating IS_WATERING");
}

void startMotor()
{
	digitalWrite(WATER_PUMP_PIN, HIGH);
	digitalWrite(PUMP_SUPPLIMENT_1, HIGH);
	digitalWrite(PUMP_SUPPLIMENT_2, HIGH);
}

void stopMotor()
{
	digitalWrite(WATER_PUMP_PIN, LOW);
	digitalWrite(PUMP_SUPPLIMENT_1, LOW);
	digitalWrite(PUMP_SUPPLIMENT_2, LOW);
}

// Firebase.ready() should be called repeatedly to handle authentication tasks.

// if (Firebase.ready() && (millis() - sendDataPrevMillis > 15000 || sendDataPrevMillis == 0))
// {
//     sendDataPrevMillis = millis();

//     Serial.printf("Set bool... %s\n", Firebase.RTDB.setBool(&fbdo, F("/test/bool"), count % 2 == 0) ? "ok" : fbdo.errorReason().c_str());
//     Serial.printf("Get bool... %s\n", Firebase.RTDB.getBool(&fbdo, FPSTR("/test/bool")) ? fbdo.to<bool>() ? "true" : "false" : fbdo.errorReason().c_str());

//     bool bVal;
//     Serial.printf("Get bool ref... %s\n", Firebase.RTDB.getBool(&fbdo, F("/test/bool"), &bVal) ? bVal ? "true" : "false" : fbdo.errorReason().c_str());
//     Serial.printf("Set int... %s\n", Firebase.RTDB.setInt(&fbdo, F("/test/int"), count) ? "ok" : fbdo.errorReason().c_str());
//     Serial.printf("Get int... %s\n", Firebase.RTDB.getInt(&fbdo, F("/test/int")) ? String(fbdo.to<int>()).c_str() : fbdo.errorReason().c_str());

//     int iVal = 0;
//     Serial.printf("Get int ref... %s\n", Firebase.RTDB.getInt(&fbdo, F("/test/int"), &iVal) ? String(iVal).c_str() : fbdo.errorReason().c_str());
//     Serial.printf("Set float... %s\n", Firebase.RTDB.setFloat(&fbdo, F("/test/float"), count + 10.2) ? "ok" : fbdo.errorReason().c_str());
//     Serial.printf("Get float... %s\n", Firebase.RTDB.getFloat(&fbdo, F("/test/float")) ? String(fbdo.to<float>()).c_str() : fbdo.errorReason().c_str());
//     Serial.printf("Set double... %s\n", Firebase.RTDB.setDouble(&fbdo, F("/test/double"), count + 35.517549723765) ? "ok" : fbdo.errorReason().c_str());
//     Serial.printf("Get double... %s\n", Firebase.RTDB.getDouble(&fbdo, F("/test/double")) ? String(fbdo.to<double>()).c_str() : fbdo.errorReason().c_str());
//     Serial.printf("Set string... %s\n", Firebase.RTDB.setString(&fbdo, F("/test/string"), F("Hello World!")) ? "ok" : fbdo.errorReason().c_str());
//     Serial.printf("Get string... %s\n", Firebase.RTDB.getString(&fbdo, F("/test/string")) ? fbdo.to<const char *>() : fbdo.errorReason().c_str());

//     // For the usage of FirebaseJson, see examples/FirebaseJson/BasicUsage/Create_Edit_Parse.ino
//     FirebaseJson json;

//     if (count == 0)
//     {
//         json.set("value/round/" + String(count), F("cool!"));
//         json.set(F("value/ts/.sv"), F("timestamp"));
//         Serial.printf("Set json... %s\n", Firebase.RTDB.set(&fbdo, F("/test/json"), &json) ? "ok" : fbdo.errorReason().c_str());
//     }
//     else
//     {
//         json.add(String(count), F("smart!"));
//         Serial.printf("Update node... %s\n", Firebase.RTDB.updateNode(&fbdo, F("/test/json/value/round"), &json) ? "ok" : fbdo.errorReason().c_str());
//     }

// Serial.println();

/** Timeout options.

//WiFi reconnect timeout (interval) in ms (10 sec - 5 min) when WiFi disconnected.
config.timeout.wifiReconnect = 10 * 1000;

//Socket connection and SSL handshake timeout in ms (1 sec - 1 min).
config.timeout.socketConnection = 10 * 1000;

//Server response read timeout in ms (1 sec - 1 min).
config.timeout.serverResponse = 10 * 1000;

//RTDB Stream keep-alive timeout in ms (20 sec - 2 min) when no server's keep-alive event data received.
config.timeout.rtdbKeepAlive = 45 * 1000;

//RTDB Stream reconnect timeout (interval) in ms (1 sec - 1 min) when RTDB Stream closed and want to resume.
config.timeout.rtdbStreamReconnect = 1 * 1000;

//RTDB Stream error notification timeout (interval) in ms (3 sec - 30 sec). It determines how often the readStream
//will return false (error) when it called repeatedly in loop.
config.timeout.rtdbStreamError = 3 * 1000;

Note:
The function that starting the new TCP session i.e. first time server connection or previous session was closed, the function won't exit until the
time of config.timeout.socketConnection.

You can also set the TCP data sending retry with
config.tcp_data_sending_retry = 1;

*/

// For generic set/get functions.

// For generic set, use Firebase.RTDB.set(&fbdo, <path>, <any variable or value>)

// For generic get, use Firebase.RTDB.get(&fbdo, <path>).
// And check its type with fbdo.dataType() or fbdo.dataTypeEnum() and
// cast the value from it e.g. fbdo.to<int>(), fbdo.to<std::string>().

// The function, fbdo.dataType() returns types String e.g. string, boolean,
// int, float, double, json, array, blob, file and null.

// The function, fbdo.dataTypeEnum() returns type enum (number) e.g. fb_esp_rtdb_data_type_null (1),
// fb_esp_rtdb_data_type_integer, fb_esp_rtdb_data_type_float, fb_esp_rtdb_data_type_double,
// fb_esp_rtdb_data_type_boolean, fb_esp_rtdb_data_type_string, fb_esp_rtdb_data_type_json,
// fb_esp_rtdb_data_type_array, fb_esp_rtdb_data_type_blob, and fb_esp_rtdb_data_type_file (10)

//         count++;
//     }
// }
