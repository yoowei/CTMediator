//
//  TableViewController.h
//  CTMediator
//
//  Created by casa on 2016/10/20.
//  Copyright © 2016年 casa. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TableViewController : UIViewController

//测试远程调用
-(id)testRomoteWithParams:(NSDictionary *)strDic;
-(id)testRomoteWithOutParams;

@end
