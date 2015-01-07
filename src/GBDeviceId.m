//
//  GBDeviceId.m
//  facebook-ios-sdk
//
//  Created by kaijung on 2014/1/23.
//
//

#import "GBDeviceId.h"
#import "GBUtility.h"
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

@implementation GBDeviceId

@synthesize deviceIdDelegate = _deviceIdDelegate;

+ (id)getInstance:(id<GBDeviceIdDelegate>)delegate {
    
    static GBDeviceId *sharedGBDeviceId = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedGBDeviceId = [[self alloc] init];
    });
    sharedGBDeviceId.deviceIdDelegate = delegate;
    return sharedGBDeviceId;
}

- (NSString *)getMacAddress
{
    int                 mgmtInfoBase[6];
    char                *msgBuffer = NULL;
    size_t              length;
    unsigned char       macAddress[6];
    struct if_msghdr    *interfaceMsgStruct;
    struct sockaddr_dl  *socketStruct;
    NSString            *errorFlag = NULL;
    
    // Setup the management Information Base (mib)
    mgmtInfoBase[0] = CTL_NET;        // Request network subsystem
    mgmtInfoBase[1] = AF_ROUTE;       // Routing table info
    mgmtInfoBase[2] = 0;
    mgmtInfoBase[3] = AF_LINK;        // Request link layer information
    mgmtInfoBase[4] = NET_RT_IFLIST;  // Request all configured interfaces
    
    // With all configured interfaces requested, get handle index
    if ((mgmtInfoBase[5] = if_nametoindex("en0")) == 0)
        errorFlag = @"if_nametoindex failure";
    else
    {
        // Get the size of the data available (store in len)
        if (sysctl(mgmtInfoBase, 6, NULL, &length, NULL, 0) < 0)
            errorFlag = @"sysctl mgmtInfoBase failure";
        else
        {
            // Alloc memory based on above call
            if ((msgBuffer = malloc(length)) == NULL)
                errorFlag = @"buffer allocation failure";
            else
            {
                // Get system information, store in buffer
                if (sysctl(mgmtInfoBase, 6, msgBuffer, &length, NULL, 0) < 0)
                    errorFlag = @"sysctl msgBuffer failure";
            }
        }
    }
    
    // Befor going any further...
    if (errorFlag != NULL)
    {
        NSLog(@"Error: %@", errorFlag);
        return @"03000000-0000-0000-0000-000000000000";
    }
    
    // Map msgbuffer to interface message structure
    interfaceMsgStruct = (struct if_msghdr *) msgBuffer;
    
    // Map to link-level socket structure
    socketStruct = (struct sockaddr_dl *) (interfaceMsgStruct + 1);
    
    // Copy link layer address data in socket structure to an array
    memcpy(&macAddress, socketStruct->sdl_data + socketStruct->sdl_nlen, 6);
    
    // Read from char array into a string object, into traditional Mac address format
    NSString *macAddressString = [NSString stringWithFormat:@"%02X%02X%02X%02X-%02X%02X-0000-0000-000000000000",
                                  macAddress[0], macAddress[1], macAddress[2],
                                  macAddress[3], macAddress[4], macAddress[5]];
    NSLog(@"Mac Address: %@", macAddressString);
    
    // Release the buffer memory
    free(msgBuffer);
    
    return macAddressString;
}

- (void)generateDeviceId {
    NSString *systemId = @"";
    if (([[[UIDevice currentDevice] systemVersion] floatValue] < 6.0f)) {
        systemId = [systemId stringByAppendingString:@"IOS_MAC-"];
        systemId= [systemId stringByAppendingString:[self getMacAddress]];
    }
    else {
        systemId = [systemId stringByAppendingString:@"VENDOR-"];
        systemId = [systemId stringByAppendingString:[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    }
    
    if ([self.deviceIdDelegate respondsToSelector:@selector(gbDidDeviceIdGenerate:)]) {
        [_deviceIdDelegate gbDidDeviceIdGenerate:systemId];
    }
}

- (NSString *)getDeviceId {
    NSString *systemId = @"";
    if (([[[UIDevice currentDevice] systemVersion] floatValue] < 6.0f)) {
        systemId = [systemId stringByAppendingString:@"IOS_MAC-"];
        systemId= [systemId stringByAppendingString:[self getMacAddress]];
    }
    else {
        //systemId = [systemId stringByAppendingString:@"VENDOR-"];
        //systemId = [systemId stringByAppendingString:[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
        systemId = [systemId stringByAppendingString:@"ADVERTISER-"];
        systemId = [systemId stringByAppendingString:[GBUtility advertiserID]];
    }
    
    return systemId;
}

@end