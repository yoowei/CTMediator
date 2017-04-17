//
//  CTMediator.m
//  CTMediator
//
//  Created by casa on 16/3/13.
//  Copyright © 2016年 casa. All rights reserved.
//

#import "CTMediator.h"
#import <objc/runtime.h>

@interface CTMediator ()

@property (nonatomic, strong) NSMutableDictionary *cachedTarget;

@end

@implementation CTMediator

#pragma mark - public methods
+ (instancetype)sharedInstance
{
    static CTMediator *mediator;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mediator = [[CTMediator alloc] init];
    });
    return mediator;
}

/*
 scheme://[target]/[action]?[params]
 url sample:
 aaa://targetA/actionB?id=1234
 */

- (id)performActionWithUrl:(NSURL *)url completion:(void (^)(NSDictionary *))completion
{
    if (![url.scheme isEqualToString:@"yooweiScheme"]) {
        // 这里就是针对远程app调用404的简单处理了
        return @(NO);
    }
    //**************************************************补充******************
    NSURL *urll = [NSURL URLWithString:
                   @"http://some-site.com:999/dir1/dir2;param?field-1=value-1&field-2=value-2#anchor1"];
    
    NSLog(@"Scheme: %@", [urll scheme]);//Scheme: http
    NSLog(@"Host: %@", [urll host]);//Host: some-site.com
    NSLog(@"Port: %@", [urll port]);//Port: 999
    NSLog(@"Path: %@", [urll path]);//Path: /dir1/dir2
    NSLog(@"Relative path: %@", [urll relativePath]);//Relative path: /dir1/dir2
    NSLog(@"Path components as array: %@", [urll pathComponents]);//Path components as array: [/,dir1,dir2]
    NSLog(@"Parameter string: %@", [urll parameterString]);//Parameter string: param
    NSLog(@"Query: %@", [urll query]);//Query: field-1=value-1&field-2=value-2
    NSLog(@"Fragment: %@", [urll fragment]);//Fragment: anchor1
    //**************************************************补充******************
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    NSString *urlString = [url query];
    if (urlString&&![urlString isEqualToString:@""]) {
        for (NSString *param in [urlString componentsSeparatedByString:@"&"]) {
            NSArray *elts = [param componentsSeparatedByString:@"="];
            if ([elts count] < 2)
                continue;
            [params setObject:[elts lastObject] forKey:[elts firstObject]];
        }
        
    }
    // 这里这么写主要是出于安全考虑，防止黑客通过远程方式调用本地模块。这里的做法足以应对绝大多数场景，如果要求更加严苛，也可以做更加复杂的安全逻辑。
    NSString *actionName = [url.path stringByReplacingOccurrencesOfString:@"/" withString:@""];
    if ([actionName hasPrefix:@"native"]) {
        return @(NO);
    }
    
    // 这个demo针对URL的路由处理非常简单，就只是取对应的target名字和method名字，但这已经足以应对绝大部份需求。如果需要拓展，可以在这个方法调用之前加入完整的路由逻辑
    id result = [self performTarget:url.host action:actionName params:params shouldCacheTarget:NO];
    if (completion) {
        if (result) {
            completion(@{@"result":result});
        } else {
            completion(nil);
        }
    }
    return result;
}

- (id)performTarget:(NSString *)targetName action:(NSString *)actionName params:(NSDictionary *)params shouldCacheTarget:(BOOL)shouldCacheTarget
{
    
    NSString *targetClassString = [NSString stringWithFormat:@"%@", targetName];
    NSString *actionString = [NSString stringWithFormat:@"%@", actionName];//注意带参数的方法名字和不带参数的方法名字不同
    
    NSObject *target = self.cachedTarget[targetClassString];
    if (target == nil) {
        targetClass = NSClassFromString(targetClassString);
        target = [[targetClass alloc] init];
    }
    
    SEL action = NSSelectorFromString(actionString);
    
    if (target == nil) {
        // 这里是处理无响应请求的地方之一，这个demo做得比较简单，如果没有可以响应的target，就直接return了。实际开发过程中是可以事先给一个固定的target专门用于在这个时候顶上，然后处理这种请求的
        return nil;
    }
    
    if (shouldCacheTarget) {
        self.cachedTarget[targetClassString] = target;
    }

    if ([target respondsToSelector:action]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        
        if (params&&params.count>0) {
            return [target performSelector:action withObject:params];
        }
        return [target performSelector:action];
        
#pragma clang diagnostic pop
    } else {
        // 有可能target是Swift对象
        actionString = [NSString stringWithFormat:@"Action_%@WithParams:", actionName];
        action = NSSelectorFromString(actionString);
        if ([target respondsToSelector:action]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            
            if (params&&params.count>0) {
                return [target performSelector:action withObject:params];
            }
            return [target performSelector:action];
#pragma clang diagnostic pop
        } else {
            // 这里是处理无响应请求的地方，如果无响应，则尝试调用对应target的notFound方法统一处理
            SEL action = NSSelectorFromString(@"notFound:");
            if ([target respondsToSelector:action]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                return [target performSelector:action withObject:params];
#pragma clang diagnostic pop
            } else {
                // 这里也是处理无响应请求的地方，在notFound都没有的时候，这个demo是直接return了。实际开发过程中，可以用前面提到的固定的target顶上的。
                [self.cachedTarget removeObjectForKey:targetClassString];
                return nil;
            }
        }
    }
}

- (void)releaseCachedTargetWithTargetName:(NSString *)targetName
{
    NSString *targetClassString = [NSString stringWithFormat:@"%@", targetName];
    [self.cachedTarget removeObjectForKey:targetClassString];
}

#pragma mark - getters and setters
- (NSMutableDictionary *)cachedTarget
{
    if (_cachedTarget == nil) {
        _cachedTarget = [[NSMutableDictionary alloc] init];
    }
    return _cachedTarget;
}

@end
