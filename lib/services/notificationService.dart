import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

mixin PushNotificationService {
  static Future<String> getAccessToken() async {
    final serviceAccountJson = {
      "type": "service_account",
      "project_id": "cockster-e477a",
      "private_key_id": "1aaa335c5b6b83b5fc3dce0ad66dc8b7e2feeb29",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC3Po9yarT2eCwJ\n7KxZ/gkUWWr1VYI5n+cFbO3fgwCSqQAvdCqYNXEJu6inlVVODy/8MGfXUhpEEzDw\n5RRG51vZEfBYoIdNb9XjVdy5O9i2jL0reW58Ha3YEiSo8XHMXiDUfu3Fm+UUHyI6\n6DlYlnPgTSELFRsLCUXzQDYQsOKDx/ab2QtZZw+3DCYi6rsk0kAL3AlURiDmUmi3\nvFyAZUhO1NyS+B4p9mEWVgyy2VTpUDRsyDqe41h86u6YinrFeTiH0aJLg25vd2o+\nHftXHRqVhlbWWq9A5fo+sd8+uw8gygSYD1EjsWUOqnjORJqtx8mAQyKX9o7CaSSs\nx5QdTl43AgMBAAECggEAE4PWnA1QK2V97yqk6kqbJe8l7G3IWiG05UeGB8U4VOYp\nrmQVOzOJz8sL+Zj2RkNozVdMX8qPIIvYrPcAk1KFXhdCfPXPowgTg8v7n0CH4l0X\nsl8SzKYOgxHflJxuDaFCps7DvMVO/rcYGqTroosXWR5ts/Px9tlseSzv9RQZc4Y0\nisT06dOmo9uzlyGngIr7ua+8vDkQGBJvZ92dsFu01AURTmcZbJNfOAYJ6uFo9ZpR\n2LOL6UAj8IQDanSEEX2tYOgj2R33lDt38LUJufjBhjD+A7zqIBxm5T0esa/cUMyX\n/LfSvxaQ8p+0MK5VV+ncHwxJmUr1/Sqrz/m2pldiHQKBgQDhNRMTsgHz5Me4MmuS\nraa6c1CZj6Pg1jkvhPBB4hJt7wutYu0i1KGhUaKlGIS0PSrs0+FDSAXtnoxrUhBr\n+A7aQ5DRRI9LviQTxqixzYsTgoV9td1jHlUP2hw2+zVhuiKPe+ZQyMY+Y3NTcLOu\nKO2hdHw9iDIB7YuIZR248UR1GwKBgQDQTKhz2zz3A4hlsV0KtjQAz+5cwGegNibZ\ntl0OiKHHcIiZaSMRWkDlIS1TzJryZHcFNTHXhyHjz7e8kZ2sEA1M6hiNWGMxHlVU\nlu3tKU60KePrWQ0Cl88atk3z3a5tbV6jsvQvZiYvMI5Ii3NSu9zspeLuLGAFe10I\nllIBdnV5FQKBgQCGmtVrKTMXln907dX0FoyX1oKvNfZqVUBa0adUiY4gXQdqu70m\n21Y7+HIxIWV34TN91+pE75BzhRdCsgsUrXAbLtUo70SCrgQcOdnsZAEjSRkGmSPY\nsXGABwpkJmOypLExd4micU5kTcbJcYxDpTzbCqeTk4roMhX7EQzh1HrpTwKBgQCR\nNl/ZJOYDbjsQae1rIkpupoaNsrSLRDUhYbjOAQKHfzQ7fsgruLe1BMQMv37lrJQs\n1UDB+DrwDkcQ9pLs+OPM0wX6w7ui6nqiVfXYeAueHfX+hD5FqH+BJ8aAU/Ld5nkr\ntf31bUkBbOBEQrNK4hzJ/XuOfvER4UaiTekti9+pYQKBgE4PsAtOA/G4CKCwFy/L\nCDUXJ5xKNNEVP15S/3LHuk4SXiqjr7In3OllqxXlVgc9Pm2IHRzW6mGUPtN6v01P\nPp9ZRM2jnUUPrWsTV0+0eBKW4YejA6jdmTI5OErE63aWyDtVlfpTKfE9Hksb/t/j\nv2G054kr9I8nGmsP77/UhWvr\n-----END PRIVATE KEY-----\n",
      "client_email":
          "firebase-adminsdk-fbsvc@cockster-e477a.iam.gserviceaccount.com",
      "client_id": "101115523759407886121",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
          "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
          "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40cockster-e477a.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com",
    };

    List<String> scopes = [
      "https://www.googleapis.com/auth/firebase.messaging",
      "https://www.googleapis.com/auth/userinfo.email",
      "https://www.googleapis.com/auth/firebase.database",
    ];

    http.Client client = await auth.clientViaServiceAccount(
      auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
      scopes,
    );

    auth.AccessCredentials credentials = await auth
        .obtainAccessCredentialsViaServiceAccount(
          auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
          scopes,
          client,
        );

    client.close();
    return credentials.accessToken.data;
  }
}
