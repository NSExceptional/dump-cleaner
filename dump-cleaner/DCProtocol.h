//
//  DCProtocol.h
//  dump-cleaner
//
//  Created by Tanner on 7/13/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCInterface.h"


@interface DCProtocol : DCObject <DCInterface>

@property (nonatomic, readonly) NSString *name;

@end
