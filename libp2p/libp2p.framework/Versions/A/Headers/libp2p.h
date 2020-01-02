//
//  libp2p.h
//  libp2p
//
//  Created by actantion on 2019/9/11.
//  Copyright © 2019 actantion. All rights reserved.
//

#import <Foundation/Foundation.h>


//! Project version number for libp2p.
FOUNDATION_EXPORT double libp2pVersionNumber;

//! Project version string for libp2p.
FOUNDATION_EXPORT const unsigned char libp2pVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <libp2p/PublicHeader.h>


@interface LibP2P : NSObject

+(void)SayHello;

+(NSString*) InitP2pNetwork:(NSString*) local_ip: (NSInteger)local_port: (NSString*)bootstrap: (NSString*)conf_path: (NSString*)version: (NSString*) prikey;
+(NSInteger) GetSocketId;
+(NSString*) GetVpnNodes:(NSString*) country: (Boolean) route;
+(NSString*) GetTransactions;
+(UInt64) GetBalance;
+(void) ResetTransport:(NSString*) local_ip: (NSInteger)local_port;
+(NSString*) GetPublicKey;

+(NSString*) getMethod;
+(NSString*) getChoosedCountry;
+(UInt32) changeStrIp: (NSString*) ip;
+(NSString*) getPublicKeyEx;
+ (NSString *)HexDecode:(NSString *)hexString;
+ (NSString *)HexEncode:(NSData *)data;
+ (NSString *)checkVersion;
+ (NSString *)checkVip;
+ (NSString *)payforVpn:(NSString *)acc: (NSString *)gid: (NSInteger)amount;
+ (NSString *)resetPrivateKey:(NSString *)prikey;
+ (void) createAccoun;
@end
