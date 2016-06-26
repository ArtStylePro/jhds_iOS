//
//  DMAPIManager.h
//  DrawMaster
//
//  Created by git on 16/6/23.
//  Copyright © 2016年 QuanGe. All rights reserved.
//

#import <AFNetworking/AFNetworking.h>

typedef NS_ENUM(NSInteger, DMAPIReturnType)
{
    DMAPIManagerReturnTypeDic,
    DMAPIManagerReturnTypeArray,
    DMAPIManagerReturnTypeStr,
    DMAPIManagerReturnTypeValue,
    DMAPIManagerReturnTypePlain,
    DMAPIManagerReturnTypeM3u8,
    DMAPIManagerReturnTypeData
    
};

@interface DMAPIManager : AFHTTPRequestOperationManager
+ (instancetype)sharedManager;

- (RACSignal *)fetchCopyNumWithType:(NSString*)type;
- (RACSignal *)fetchCopyListWithType:(NSString*)type PageIndex:(NSString*)page;

- (RACSignal *)fetchLearnNumWithType:(NSString*)type;
- (RACSignal *)fetchLearnListWithType:(NSString*)type PageIndex:(NSString*)page;

@end
