import { NativeModules, NativeEventEmitter, Platform } from "react-native"
const notificationModule = NativeModules.BlitzNotifications
const eventEmitter = new NativeEventEmitter(notificationModule)

export default {
  getDeviceId: (callback) => {
    // if (Platform.OS === 'android') {
    //     if (notificationModule) {
    //         if (notificationModule.registerForToken) {
    //             notificationModule.registerForToken(deviceId => {
    //                 callback(deviceId)
    //             })
    //         }
    //     }
    // } else {
    let event = eventEmitter.addListener("deviceRegistered", (deviceId) => {
      callback(deviceId)
      eventEmitter.removeSubscription(event)
    })
    notificationModule.registerForToken()
    // }
  },
  getLastNotificationData: (callback, errorCallback) => {
    if (Platform.OS === "android") {
      notificationModule.getLastNotificationData((notification) => {
        console.log("notification:", notification)
        try {
          if (typeof notification === "string") {
            let data = JSON.parse(notification)
            callback(data)
          } else {
            throw "Invalid data provided"
          }
        } catch (e) {
          errorCallback(e)
        }
      })
    } else {
      eventEmitter.addListener("onNotificationTap", (event) => {
        // console.log('event event ',event)
        if (event) {
          let data = Platform.OS === "ios" ? event : JSON.parse(event)
          callback(data)
        }
      })
      notificationModule.getLastNotificationData((notification) => {
        try {
          callback(notification)
        } catch (e) {
          errorCallback(e)
        }
      })
    }
  },
  onMessageReceived: (callback) => {
    const subscription = eventEmitter.addListener(
      "notificationReceived",
      (event) => {
        console.log("event event ", event)
        if (event) {
          let data = Platform.OS === "ios" ? event : JSON.parse(event)
          callback(data)
        }
      }
    )
    return subscription
  },
  onNotificationTapped: (callback) => {
    if (Platform.OS === "android") {
      eventEmitter.addListener("onNotificationTapped", (event) => {
        callback(event)
      })
    } else {
      console.warn(
        "getLastNotificationData is only available on android platform"
      )
    }
  },
  requestPermission(permissions) {
    if (isAndroid) {
      return Promise.resolve(1);
    }

    const defaultPermissions = {
      alert: true,
      announcement: false,
      badge: true,
      carPlay: true,
      provisional: false,
      sound: true,
    };

    if (!permissions) {
      return notificationModule.requestPermission(defaultPermissions);
    }

    if (!isObject(permissions)) {
      throw new Error('firebase.messaging().requestPermission(*) expected an object value.');
    }

    Object.entries(permissions).forEach(([key, value]) => {
      if (!hasOwnProperty(defaultPermissions, key)) {
        throw new Error(
          `firebase.messaging().requestPermission(*) unexpected key "${key}" provided to permissions object.`,
        );
      }

      if (!isBoolean(value)) {
        throw new Error(
          `firebase.messaging().requestPermission(*) the permission "${key}" expected a boolean value.`,
        );
      }

      defaultPermissions[key] = value;
    });

    return notificationModule.requestPermission(defaultPermissions);
  },
  hasPermission: () => {
    return notificationModule.hasPermission();
  },
  getToken: () => {
    return notificationModule.getToken(
      'messagingSenderId',
      'FCM',
    );
  },
  removeAllDeliveredNotifications: () => {
    notificationModule.removeAllDeliveredNotifications()
  },
}
