//----------------------------------------------------------------
//  Copyright (c) Microsoft Corporation. All rights reserved.
//----------------------------------------------------------------

#import <Foundation/Foundation.h>

#import "ANHHttpClientProtocol.h"

@interface ANHHttpClient : NSObject <ANHHttpClientProtocol>

/**
 * Creates an instance of MSHttpClient.
 *
 * @return A new instance of MSHttpClient.
 */
- (instancetype)init;

/**
 * Creates an instance of MSHttpClient.
 *
 * @param maxHttpConnectionsPerHost The maximum number of connections that can be open for a single host at once.
 *
 * @return A new instance of MSHttpClient.
 */
- (instancetype)initWithMaxHttpConnectionsPerHost:(NSInteger)maxHttpConnectionsPerHost;

@end
