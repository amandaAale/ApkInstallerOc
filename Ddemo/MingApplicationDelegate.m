//
//  MingApplicationDelegate.m
//  Ddemo
//
//  Created by Ming Wang on 8/24/14.
//  Copyright (c) 2014 Ming Wang. All rights reserved.
//

#import "MingApplicationDelegate.h"

@implementation MingApplicationDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
    NSLog(@"Application is finished!!");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self detectUSB];
    });
}


typedef struct MyPrivateData {
    io_object_t				notification;
    IOUSBDeviceInterface	**deviceInterface;
    CFStringRef				deviceName;
    UInt32					locationID;
} MyPrivateData;

static IONotificationPortRef	gNotifyPort;
static io_iterator_t			gAddedIter;
static CFRunLoopRef				gRunLoop;
static bool                     gNotifyStarted;


void DeviceNotification(void *refCon, io_service_t service, natural_t messageType, void *messageArgument)
{
    kern_return_t	kr;
    MyPrivateData	*privateDataRef = (MyPrivateData *) refCon;
    
    if (messageType == kIOMessageServiceIsTerminated) {
        NSLog(@"Device removed.\n");
        
        if (gNotifyStarted) {
            sendNotification();
        }
        
        // Dump our private data to stderr just to see what it looks like.
        NSLog(@"privateDataRef->deviceName: %@",privateDataRef->deviceName);
        
        NSLog(@"privateDataRef->locationID: 0x%x.\n\n", (unsigned int)privateDataRef->locationID);
        
        // Free the data we're no longer using now that the device is going away
        CFRelease(privateDataRef->deviceName);
        
        if (privateDataRef->deviceInterface) {
            kr = (*privateDataRef->deviceInterface)->Release(privateDataRef->deviceInterface);
        }
        
        kr = IOObjectRelease(privateDataRef->notification);
        
        free(privateDataRef);
    }
}


void DeviceAdded(void *refCon, io_iterator_t iterator)
{
    kern_return_t		kr;
    io_service_t		usbDevice;
    IOCFPlugInInterface	**plugInInterface = NULL;
    SInt32				score;
    HRESULT 			res;
    
    while ((usbDevice = IOIteratorNext(iterator))) {
        io_name_t		deviceName;
        CFStringRef		deviceNameAsCFString;
        MyPrivateData	*privateDataRef = NULL;
        UInt32			locationID;
        
        NSLog(@"Device added.\n");
        if (gNotifyStarted) {
            sendNotification();
        }
        
        // Add some app-specific information about this device.
        // Create a buffer to hold the data.
        privateDataRef = malloc(sizeof(MyPrivateData));
        bzero(privateDataRef, sizeof(MyPrivateData));
        
        // Get the USB device's name.
        kr = IORegistryEntryGetName(usbDevice, deviceName);
        if (KERN_SUCCESS != kr) {
            deviceName[0] = '\0';
        }
        
        deviceNameAsCFString = CFStringCreateWithCString(kCFAllocatorDefault, deviceName,
                                                         kCFStringEncodingASCII);

        
        // Dump our data to stderr just to see what it looks like.
        NSLog(@"deviceName: %@", deviceNameAsCFString);
        
        // Save the device's name to our private data.
        privateDataRef->deviceName = deviceNameAsCFString;
        
        // Now, get the locationID of this device. In order to do this, we need to create an IOUSBDeviceInterface
        // for our device. This will create the necessary connections between our userland application and the
        // kernel object for the USB Device.
        kr = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID,
                                               &plugInInterface, &score);
        
        if ((kIOReturnSuccess != kr) || !plugInInterface) {
            NSLog(@"IOCreatePlugInInterfaceForService returned 0x%08x.\n", kr);
            continue;
        }
        
        // Use the plugin interface to retrieve the device interface.
        res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
                                                 (LPVOID*) &privateDataRef->deviceInterface);
        
        // Now done with the plugin interface.
        (*plugInInterface)->Release(plugInInterface);
        
        if (res || privateDataRef->deviceInterface == NULL) {
            NSLog(@"QueryInterface returned %d.\n", (int) res);
            continue;
        }
        
        // Now that we have the IOUSBDeviceInterface, we can call the routines in IOUSBLib.h.
        // In this case, fetch the locationID. The locationID uniquely identifies the device
        // and will remain the same, even across reboots, so long as the bus topology doesn't change.
        
        kr = (*privateDataRef->deviceInterface)->GetLocationID(privateDataRef->deviceInterface, &locationID);
        if (KERN_SUCCESS != kr) {
            NSLog(@"GetLocationID returned 0x%08x.\n", kr);
            continue;
        }
        else {
            NSLog(@"Location ID: 0x%x\n\n", (unsigned int)locationID);
        }
        
        privateDataRef->locationID = locationID;
        
        // Register for an interest notification of this device being removed. Use a reference to our
        // private data as the refCon which will be passed to the notification callback.
        kr = IOServiceAddInterestNotification(gNotifyPort,						// notifyPort
                                              usbDevice,						// service
                                              kIOGeneralInterest,				// interestType
                                              DeviceNotification,				// callback
                                              privateDataRef,					// refCon
                                              &(privateDataRef->notification)	// notification
                                              );
        
        if (KERN_SUCCESS != kr) {
            printf("IOServiceAddInterestNotification returned 0x%08x.\n", kr);
        }
        
        // Done with this USB device; release the reference added by IOIteratorNext
        kr = IOObjectRelease(usbDevice);
    }
}

-  (void ) detectUSB {
    gNotifyStarted = NO;
    CFMutableDictionaryRef 	matchingDict;
    CFRunLoopSourceRef		runLoopSource;
    kern_return_t			kr;
    
    matchingDict = IOServiceMatching(kIOUSBDeviceClassName);	// Interested in instances of class
    // IOUSBDevice and its subclasses
    if (matchingDict == NULL) {
        NSLog(@"IOServiceMatching returned NULL.\n");
    }
    
    gNotifyPort = IONotificationPortCreate(kIOMasterPortDefault);
    runLoopSource = IONotificationPortGetRunLoopSource(gNotifyPort);
    
    gRunLoop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(gRunLoop, runLoopSource, kCFRunLoopDefaultMode);
    
    // Now set up a notification to be called when a device is first matched by I/O Kit.
    kr = IOServiceAddMatchingNotification(gNotifyPort,					// notifyPort
                                          kIOFirstMatchNotification,	// notificationType
                                          matchingDict,					// matching
                                          DeviceAdded,					// callback
                                          NULL,							// refCon
                                          &gAddedIter					// notification
                                          );
    
    // Iterate once to get already-present devices and arm the notification
    DeviceAdded(NULL, gAddedIter);
    
    // Start the run loop. Now we'll receive notifications.
    NSLog(@"Starting run loop.\n\n");
    gNotifyStarted = YES;
    CFRunLoopRun();

    
}
 void sendNotification() {
     NSLog(@"send notification .....");
    [[NSNotificationCenter defaultCenter ] postNotificationName:@"usb" object:nil];
}
@end
