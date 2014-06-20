//
//  CCMenu.h
//  Space Cannon
//
//  Created by Michał Kozak on 06.05.2014.
//  Copyright (c) 2014 Raz Labs. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@interface CCMenu : SKNode

@property (nonatomic) int score;
@property (nonatomic) int topScore;
@property (nonatomic) BOOL touchable;

-(void)hide;
-(void)show;

@end
