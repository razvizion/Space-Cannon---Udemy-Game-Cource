//
//  CCMyScene.m
//  Space Cannon
//
//  Created by Michał Kozak on 02.05.2014.
//  Copyright (c) 2014 Raz Labs. All rights reserved.
//

#import "CCMyScene.h"
#import "CCMenu.h"
#import "CCBall.h"
#import "AVFoundation/AVFoundation.h"

@implementation CCMyScene
{
    AVAudioPlayer *_audioPlayer;
    SKNode *_mainLayer;
    CCMenu *_menu;
    SKSpriteNode *_cannon;
    SKSpriteNode *_ammoDisplay;
    SKSpriteNode *_pauseButton;
    SKSpriteNode *_resumeButton;
    SKLabelNode *_scoreLabel;
    SKLabelNode *_pointLabel;
    BOOL _didShoot;
    int _killCount;
    SKAction *_bounceSound;
    SKAction *_deepExplosionSound;
    SKAction *_explosionSound;
    SKAction *_laserSound;
    SKAction *_zapSound;
    SKAction *_shieldUpSound;
    BOOL _gameOver;
    NSUserDefaults *_userDegfaults;
    NSMutableArray *_shieldPool;
}

static const CGFloat SHOOT_SPEED = 1000.0f;
static const CGFloat HALO_LOW_ANGLE = 200.0 * M_PI /180.0;
static const CGFloat HALO_HIGH_ANGLE = 300.0 * M_PI /180.0;
static const CGFloat HALO_SPEED = 100.0f;

static const uint32_t kCCHaloCategory       = 0x1 << 0;
static const uint32_t kCCBallCategory       = 0x1 << 1;
static const uint32_t kCCEdgeCategory       = 0x1 << 2;
static const uint32_t kCCShieldCategory     = 0x1 << 3;
static const uint32_t kCCLifeBarCategory    = 0x1 << 4;
static const uint32_t kCCShieldUpCategory   = 0x1 << 5;
static const uint32_t kCCMultiUpCategory   = 0x1 << 6;

static NSString * const kCCKeyTopScore = @"TopScore";

static inline CGVector radiansToVector(CGFloat radians){
    
    CGVector vector;
    vector.dx = cosf(radians);
    vector.dy = sinf(radians);
    return vector;
}
static inline CGFloat randomInRange(CGFloat low, CGFloat high){
    CGFloat value = arc4random_uniform(UINT32_MAX)/ (CGFloat)UINT32_MAX;
    return value * (high-low) +low;
}

-(id)initWithSize:(CGSize)size {
    if (self = [super initWithSize:size]) {
        /* Setup your scene here */
        
        // Turn off gravity
        
        self.physicsWorld.gravity = CGVectorMake(0.0, 0.0);
        self.physicsWorld.contactDelegate = self;
        
        SKSpriteNode *background = [SKSpriteNode spriteNodeWithImageNamed:@"Starfield"];
        background.position = CGPointZero;
        background.anchorPoint = CGPointZero;
        background.blendMode = SKBlendModeReplace;
        
        [self addChild:background];
        
        //Add edges
        
        SKNode *leftEdge = [[SKNode alloc]init];
        leftEdge.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointZero toPoint:CGPointMake(0.0, self.size.height +100)];
        leftEdge.physicsBody.categoryBitMask = kCCEdgeCategory;
        leftEdge.position = CGPointZero;
        
        [self addChild:leftEdge];
        
        
        SKNode *rightEdge = [[SKNode alloc]init];
        rightEdge.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointZero toPoint:CGPointMake(0.0, self.size.height +100)];
        rightEdge.position = CGPointMake(self.size.width, 0.0);
        rightEdge.physicsBody.categoryBitMask = kCCEdgeCategory;
        
        [self addChild:rightEdge];
        
        //Add main Layer
        _mainLayer = [[SKNode alloc]init];
        [self addChild:_mainLayer];
        
        //add cannonc
        _cannon = [SKSpriteNode spriteNodeWithImageNamed:@"Cannon"];
        _cannon.position = CGPointMake(self.size.width *0.5, 0.0);
        [self addChild:_cannon];
        
        //create cannon rotation actions
        SKAction *rotateCannon = [SKAction sequence:@[[SKAction rotateByAngle:M_PI duration:2],[SKAction rotateByAngle:-M_PI duration:2]]];
        [_cannon runAction:[SKAction repeatActionForever:rotateCannon]];
        
        // Create spawn halo actions.
        SKAction *spawnHalo = [SKAction sequence:@[[SKAction waitForDuration:2 withRange:1],[SKAction performSelector:@selector(spawnHalo) onTarget:self]]];
        [self runAction:[SKAction repeatActionForever:spawnHalo] withKey:@"SpawnHalo"];
        
        SKAction *spawnShieldPowerUp = [SKAction sequence:@[[SKAction waitForDuration:15 withRange:4],[SKAction performSelector:@selector(spawnShieldPowerUp) onTarget:self]]];
        [self runAction:[SKAction repeatActionForever:spawnShieldPowerUp]];
        
        
        //Setup ammo
        
        _ammoDisplay = [SKSpriteNode spriteNodeWithImageNamed:@"Ammo5"];
        _ammoDisplay.anchorPoint = CGPointMake(0.5,0.0);
        _ammoDisplay.position = _cannon.position;
        
        [self addChild:_ammoDisplay];
        
        
        
        SKAction *incrementAmmo = [SKAction sequence:@[[SKAction waitForDuration:1],[SKAction runBlock:^{
            
            if(!self.multiMode){
               self.ammo ++;
            }
            
        }]]];
        [self runAction:[SKAction repeatActionForever:incrementAmmo]];
        
        
        //Steup shield pool
        
        _shieldPool = [[NSMutableArray alloc]init];
        
        // Setup shields
        
        for (int i =0; i < 6; i++) {
            SKSpriteNode *shield = [SKSpriteNode spriteNodeWithImageNamed:@"Block"];
            shield.position = CGPointMake(35 + (50 *i), 90);
            shield.name=@"shield";
            shield.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(42, 9)];
            shield.physicsBody.categoryBitMask = kCCShieldCategory;
            shield.physicsBody.collisionBitMask = 0;
            [_shieldPool addObject:shield];
        }
        
        //Setup pasue button
        
        _pauseButton = [SKSpriteNode spriteNodeWithImageNamed:@"PauseButton"];
        _pauseButton.position = CGPointMake(self.size.width -30, 20);
        [self addChild:_pauseButton];
        
        //Setup resume button
        
        _resumeButton = [SKSpriteNode spriteNodeWithImageNamed:@"ResumeButton"];
        _resumeButton.position = CGPointMake(self.size.width * 0.5, self.size.height * 0.5);
        [self addChild:_resumeButton];
        
        
        _scoreLabel = [SKLabelNode labelNodeWithFontNamed:@"DIN Alternate"];
        _scoreLabel.position = CGPointMake(15, 10);
        _scoreLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
        _scoreLabel.fontSize=15;
        [self addChild:_scoreLabel];
        
        // Setup multiplier Label
        _pointLabel = [SKLabelNode labelNodeWithFontNamed:@"DIN Alternate"];
        _pointLabel.position = CGPointMake(15, 30);
        _pointLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
        _pointLabel.fontSize=15;
        [self addChild:_pointLabel];
        
        
        // Sounds
        _bounceSound = [SKAction playSoundFileNamed:@"Bounce.caf" waitForCompletion:NO];
        _laserSound = [SKAction playSoundFileNamed:@"Laser.caf" waitForCompletion:NO];
        _zapSound = [SKAction playSoundFileNamed:@"Zap.caf" waitForCompletion:NO];
        _deepExplosionSound = [SKAction playSoundFileNamed:@"DeepExplosion.caf" waitForCompletion:NO];
        _explosionSound = [SKAction playSoundFileNamed:@"Explosion.caf" waitForCompletion:NO];
        _shieldUpSound = [SKAction playSoundFileNamed:@"ShieldUp.caf" waitForCompletion:NO];
        // Set Menu
        
        _menu =  [[CCMenu alloc]init];
        
        _menu.position = CGPointMake(self.size.width * 0.5, self.size.height -200);
        [self addChild:_menu];
        
        
        
        self.ammo = 5;
        self.score=0;
        self.pointValue=1;
        
        _gameOver = YES;
        _scoreLabel.hidden = YES;
        _pointLabel.hidden = YES;
        _pauseButton.hidden = YES;
        _resumeButton.hidden = YES;
        // Load TopScore
        
        _userDegfaults = [NSUserDefaults standardUserDefaults];
        
        _menu.topScore = (int)[_userDegfaults integerForKey:kCCKeyTopScore];
        
        //Load music
        
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"ObservingTheStar" withExtension:@"caf"];
        NSError *error = nil;
        
        _audioPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:url error:&error];
        if(!_audioPlayer){
            NSLog(@"Error loading audio player %@",error);
        }else{
            _audioPlayer.numberOfLoops = -1;
            _audioPlayer.volume = 0.1;
            [_audioPlayer play];
        }
        
    }
    return self;
}

-(void)newGame
{
    
    [_mainLayer removeAllChildren];
    
    while (_shieldPool.count>0) {
        [_mainLayer addChild:[_shieldPool objectAtIndex:0]];
        [_shieldPool removeObjectAtIndex:0];
    }
    
    SKSpriteNode *lifeBar = [SKSpriteNode spriteNodeWithImageNamed:@"BlueBar"];
    lifeBar.position = CGPointMake(self.size.width*0.5, 70);
    lifeBar.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointMake(-lifeBar.size.width *0.5, 0) toPoint:CGPointMake(lifeBar.size.width *0.5, 0)];
    lifeBar.physicsBody.categoryBitMask = kCCLifeBarCategory;
    [_mainLayer addChild:lifeBar];
    
    
    // Set initial values
    [self actionForKey:@"SpawnHalo"].speed = 1.0;
    self.ammo = 5;
    self.score=0;
    _killCount = 0;
    self.multiMode = NO;
    self.pointValue=1;
    _scoreLabel.hidden = NO;
    _pointLabel.hidden = NO;
    _pauseButton.hidden = NO;
    [_menu hide];
    _gameOver = NO;
}

-(void)setAmmo:(int)ammo
{
    if(ammo >= 0 && ammo <=5){
        _ammo = ammo;
        _ammoDisplay.texture = [SKTexture textureWithImageNamed:[NSString stringWithFormat:@"Ammo%d",ammo]];
    }
}
-(void)setScore:(int)score{
    _score = score;
    _scoreLabel.text = [NSString stringWithFormat:@"Score: %d",score];
}

-(void)setPointValue:(int)pointValue
{
    _pointValue = pointValue;
    _pointLabel.text = [NSString stringWithFormat:@"Points: x%d",pointValue];
}

-(void)setMultiMode:(BOOL)multiMode
{
    _multiMode = multiMode;
    if(multiMode){
        _cannon.texture = [SKTexture textureWithImageNamed:@"GreenCannon"];
    }
    else{
        _cannon.texture = [SKTexture textureWithImageNamed:@"Cannon"];
    }
}
-(void)setGamePaused:(BOOL)gamePaused
{
    if(!_gameOver){
    _gamePaused = gamePaused;
    _pauseButton.hidden = gamePaused;
    _resumeButton.hidden = !gamePaused;
    self.paused = gamePaused;
    }
}

-(void)shoot
{
    
    [self runAction:_laserSound];
    CCBall *ball = [CCBall spriteNodeWithImageNamed:@"Ball"];
    ball.name = @"ball";
    CGVector rotationVector = radiansToVector(_cannon.zRotation);
    ball.position = CGPointMake(_cannon.position.x + (_cannon.size.width *0.5 * rotationVector.dx),
                                _cannon.position.y + (_cannon.size.height*0.5 * rotationVector.dy));
    [_mainLayer addChild:ball];
    
    ball.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:6.0];
    ball.physicsBody.velocity = CGVectorMake(rotationVector.dx * SHOOT_SPEED, rotationVector.dy * SHOOT_SPEED);
    ball.physicsBody.restitution = 1.0;
    ball.physicsBody.linearDamping = 0.0;
    ball.physicsBody.friction = 0.0;
    ball.physicsBody.categoryBitMask = kCCBallCategory;
    ball.physicsBody.collisionBitMask = kCCEdgeCategory;
    ball.physicsBody.contactTestBitMask = kCCEdgeCategory | kCCShieldUpCategory | kCCMultiUpCategory;
    
    // Create trail.
    NSString *ballTrailPath = [[NSBundle mainBundle]pathForResource:@"BallTrail" ofType:@"sks"];
    SKEmitterNode *ballTrail = [NSKeyedUnarchiver unarchiveObjectWithFile:ballTrailPath];
    ballTrail.targetNode = _mainLayer;
    [_mainLayer addChild:ballTrail];
    ball.trail = ballTrail;
    [ball updateTrail ];
    
}

-(void)spawnHalo{
    
    //increase spawn speed.
    
    SKAction *spawnHaloAction = [self actionForKey:@"SpawnHalo"];
    
    if(spawnHaloAction.speed < 1.5){
        spawnHaloAction.speed += 0.02;
    }
    
    SKSpriteNode *halo = [SKSpriteNode spriteNodeWithImageNamed:@"Halo"];
    halo.name=@"halo";
    halo.position = CGPointMake(randomInRange(halo.size.width * 0.5, self.size.width - (halo.size.width * 0.5)), self.size.height + (halo.size.height * 0.5));
    halo.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:16.0];
    CGVector direction = radiansToVector(randomInRange(HALO_LOW_ANGLE, HALO_HIGH_ANGLE));
    halo.physicsBody.velocity = CGVectorMake(direction.dx * HALO_SPEED, direction.dy * HALO_SPEED);
    halo.physicsBody.restitution = 1.0;
    halo.physicsBody.linearDamping = 0.0;
    halo.physicsBody.friction = 0.0;
    halo.physicsBody.categoryBitMask = kCCHaloCategory;
    halo.physicsBody.collisionBitMask = kCCEdgeCategory;
    halo.physicsBody.contactTestBitMask = kCCBallCategory | kCCShieldCategory | kCCLifeBarCategory;
    
    
    
    int haloCount = 0;
    
    for (SKNode *node in _mainLayer.children) {
        if([node.name isEqualToString:@"halo"]){
            haloCount++;
        }
    }
    
    // Random poin multiplier
//    __block int haloCount = 0;
    
    
    /* HALO COUNT*/
//    [_mainLayer enumerateChildNodesWithName:@"halo" usingBlock:^(SKNode *node, BOOL *stop) {
//        haloCount++;
//    }];
    
    if(!_gameOver && haloCount == 4){
        halo.texture = [SKTexture textureWithImageNamed:@"HaloBomb"];
        halo.userData = [[NSMutableDictionary alloc] init];
        [halo.userData setValue:@YES forKey:@"Bomb"];
        
    }else if(!_gameOver && arc4random_uniform(6) == 0){
        halo.texture = [SKTexture textureWithImageNamed:@"HaloX"];
        halo.userData = [[NSMutableDictionary alloc] init];
        [halo.userData setValue:@YES forKey:@"Multiplier"];
    }
    [_mainLayer addChild:halo];
}


-(void)spawnShieldPowerUp{
    
    if(_shieldPool.count>0){
        SKSpriteNode *shieldUp = [SKSpriteNode spriteNodeWithImageNamed:@"Block"];
        shieldUp.position = CGPointMake(self.size.width + shieldUp.size.width, randomInRange(150, self.size.height-100));
        shieldUp.name=@"shieldUp";
        shieldUp.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(42, 9)];
        shieldUp.physicsBody.categoryBitMask = kCCShieldUpCategory;
        shieldUp.physicsBody.collisionBitMask = 0;
        shieldUp.physicsBody.velocity = CGVectorMake(-100, randomInRange(-40, 40));
        shieldUp.physicsBody.angularVelocity = M_PI;
        shieldUp.physicsBody.linearDamping = 0.0;
        shieldUp.physicsBody.angularDamping = 0.0;
        [_mainLayer  addChild:shieldUp];
    }
}

-(void)spawnMultiShootPowerUp{
    
    SKSpriteNode *multiUp = [SKSpriteNode spriteNodeWithImageNamed:@"MultiShotPowerUp"];
    multiUp.name = @"multiUp";
    multiUp.position = CGPointMake(-multiUp.size.width, randomInRange(150, self.size.height -100));
    multiUp.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:12.0];
    multiUp.physicsBody.categoryBitMask = kCCMultiUpCategory;
    multiUp.physicsBody.collisionBitMask = 0;
    multiUp.physicsBody.velocity = CGVectorMake(100, randomInRange(-40, 40));
    multiUp.physicsBody.angularVelocity = M_PI;
    multiUp.physicsBody.linearDamping = 0.0;
    multiUp.physicsBody.angularDamping = 0.0;
    [_mainLayer addChild:multiUp];
    
    
}

-(void)didBeginContact:(SKPhysicsContact *)contact{
    SKPhysicsBody *firstBody;
    SKPhysicsBody *secondBody;
    
    if(contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask){
        firstBody = contact.bodyA;
        secondBody = contact.bodyB;
    }else{
        firstBody = contact.bodyB;
        secondBody = contact.bodyA;
    }
    if (firstBody.categoryBitMask == kCCHaloCategory && secondBody.categoryBitMask == kCCBallCategory) {
        
        self.score += self.pointValue;
        [self addExplosion:firstBody.node.position withName:@"HaloExplosion"];
        [self runAction:_explosionSound];
        
        if([[firstBody.node.userData valueForKey:@"Multiplier"] boolValue])
        {
            self.pointValue++;
            
        }else if([[firstBody.node.userData valueForKey:@"Bomb"] boolValue]){
            firstBody.node.name=nil;
            [_mainLayer enumerateChildNodesWithName:@"halo" usingBlock:^(SKNode *node, BOOL *stop) {
                //self.score += self.pointValue;
                //if([[node.userData valueForKey:@"Multiplier"] boolValue]){
                //    self.pointValue++;
                //}
                [self addExplosion:node.position withName:@"HaloExplosion"];
                [node removeFromParent];
            }];
        }
        _killCount++;
        if(_killCount % 10 == 0){
            [self spawnMultiShootPowerUp];
        }
        
        firstBody.categoryBitMask = 0;
        [firstBody.node removeFromParent];
        [secondBody.node removeFromParent];
    }
    
    if (firstBody.categoryBitMask == kCCHaloCategory && secondBody.categoryBitMask == kCCShieldCategory) {
        
        [self addExplosion:firstBody.node.position withName:@"HaloExplosion"];
        [self runAction:_explosionSound];
        firstBody.categoryBitMask = 0;
        if([[firstBody.node.userData valueForKey:@"Bomb"] boolValue]){
            [_mainLayer enumerateChildNodesWithName:@"shield" usingBlock:^(SKNode *node, BOOL *stop) {
                [_shieldPool addObject:node];
                [node removeFromParent];
            }];
        }else {
            [_shieldPool addObject:secondBody.node];
            [secondBody.node removeFromParent];
        }
        
        [firstBody.node removeFromParent];
        
    }
    if (firstBody.categoryBitMask == kCCHaloCategory && secondBody.categoryBitMask == kCCLifeBarCategory) {
        [self addExplosion:secondBody.node.position withName:@"LifeBarExplosion"];
        [self runAction:_deepExplosionSound];
        [secondBody.node removeFromParent];
        [self gameOver];
    }
    
    
    if (firstBody.categoryBitMask == kCCBallCategory && secondBody.categoryBitMask == kCCEdgeCategory) {
        if([firstBody.node isKindOfClass:[CCBall class]]){
            ((CCBall*)firstBody.node).bounces++;
            if(((CCBall*)firstBody.node).bounces>3){
                [firstBody.node removeFromParent];
                self.pointValue =1;
            }
        }
        
        [self addExplosion:contact.contactPoint withName:@"HaloBounce"];
        [self runAction:_bounceSound];
    }
    
    if(firstBody.categoryBitMask == kCCBallCategory && secondBody.categoryBitMask == kCCShieldUpCategory){
        //if([firstBody.node isKindOfClass:[CCBall class]]){
            
        //}
        if(_shieldPool.count >0){
            int randomIndex = arc4random_uniform((int)_shieldPool.count);
            [_mainLayer addChild:[_shieldPool objectAtIndex:randomIndex]];
            [_shieldPool removeObjectAtIndex:randomIndex];
            [self runAction:_shieldUpSound];
        }
        [firstBody.node removeFromParent];
        [secondBody.node removeFromParent];
        
    }
    if(firstBody.categoryBitMask == kCCBallCategory && secondBody.categoryBitMask == kCCMultiUpCategory)
    {
        self.multiMode = YES;
        [self runAction:_shieldUpSound];
        self.ammo = 5;
        [firstBody.node removeFromParent];
        [secondBody.node removeFromParent];
    }
}

-(void)gameOver
{
    [_mainLayer enumerateChildNodesWithName:@"halo" usingBlock:^(SKNode *node, BOOL *stop) {
        [self addExplosion:node.position withName:@"HaloExplosion"];
        [node removeFromParent];
    }];
    [_mainLayer enumerateChildNodesWithName:@"ball" usingBlock:^(SKNode *node, BOOL *stop) {
        [node removeFromParent];
    }];
    [_mainLayer enumerateChildNodesWithName:@"shield" usingBlock:^(SKNode *node, BOOL *stop) {
        [_shieldPool addObject:node];
        [node removeFromParent];
    }];
    [_mainLayer enumerateChildNodesWithName:@"shieldUp" usingBlock:^(SKNode *node, BOOL *stop) {
        [node removeFromParent];
    }];
    [_mainLayer enumerateChildNodesWithName:@"multiUp" usingBlock:^(SKNode *node, BOOL *stop) {
        [node removeFromParent];
    }];
    
    _menu.score = self.score;
    if(self.score > _menu.topScore){
        _menu.topScore = self.score;
        [_userDegfaults setInteger:self.score forKey:kCCKeyTopScore];
        [_userDegfaults synchronize];
    }
    
    
    _scoreLabel.hidden = YES;
    _pointLabel.hidden = YES;
    _pauseButton.hidden = YES;
    _gameOver = YES;
    [self runAction:[SKAction waitForDuration:1.0] completion:^{
        [_menu show];
    }];
}

-(void)addExplosion:(CGPoint)position withName:(NSString *)name
{
    NSString *explosionPath = [[NSBundle mainBundle] pathForResource:name ofType:@"sks"];
    SKEmitterNode *explosion = [NSKeyedUnarchiver unarchiveObjectWithFile:explosionPath];
    
    //    SKEmitterNode *explosion = [SKEmitterNode node];
    //    explosion.particleTexture = [SKTexture textureWithImageNamed:@"spark"];
    //    explosion.particleLifetime = 1;
    //    explosion.particleBirthRate = 2000;
    //    explosion.numParticlesToEmit = 100;
    //    explosion.emissionAngleRange = 360;
    //    explosion.particleScale = 0.2;
    //    explosion.particleScaleSpeed = -0.2;
    //    explosion.particleSpeed = 200;
    //
    explosion.position = position;
    [_mainLayer addChild:explosion];
    
    SKAction *removeExplosion = [SKAction sequence:@[[SKAction waitForDuration:1.5]
                                                     ,[SKAction removeFromParent]]];
    [explosion runAction:removeExplosion];
}


-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    
    for (UITouch *touch in touches) {
        if(!_gameOver && !self.gamePaused){
           if(![_pauseButton containsPoint:[touch locationInNode:_pauseButton.parent]])
           {
                _didShoot = YES;
           }
        }
        
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches) {
        if(_gameOver && _menu.touchable){
            SKNode *n = [_menu nodeAtPoint:[touch locationInNode:_menu]];
            if([n.name isEqualToString:@"Play"]){
                [self newGame];
                
            }
        }
        else if(!_gameOver){
            if(self.gamePaused){
                if([_resumeButton containsPoint:[touch locationInNode:_resumeButton.parent]]){
                    self.gamePaused = NO;
                }
            } else {
                if([_pauseButton containsPoint:[touch locationInNode:_pauseButton.parent]]){
                    self.gamePaused = YES;
                }
            }
        }
    }
}

-(void)didSimulatePhysics{
    
    if (_didShoot == YES) {
        if(self.ammo >0){
            self.ammo--;
            [self shoot];
            if(self.multiMode){
                for (int i = 1; i < 5; i++) {
                    [self performSelector:@selector(shoot) withObject:nil afterDelay:0.1 * i];
                }
                if (self.ammo == 0){
                    self.multiMode = NO;
                    self.ammo = 5;
                }
            }
            
            
        }
        _didShoot = NO;
    }
    
    [_mainLayer enumerateChildNodesWithName:@"ball" usingBlock:^(SKNode *node, BOOL *stop) {
        if([node respondsToSelector:@selector(updateTrail)]){
            [node performSelector:@selector(updateTrail) withObject:nil afterDelay:0.0];
        }
        
        
        if(!CGRectContainsPoint(self.frame, node.position)){
            [node removeFromParent];
            self.pointValue =1;
        }
    }];
    
    [_mainLayer enumerateChildNodesWithName:@"shieldUp" usingBlock:^(SKNode *node, BOOL *stop) {
        if(node.position.x + node.frame.size.width < 0){
            [node removeFromParent];
        }
    }];
    [_mainLayer enumerateChildNodesWithName:@"multiUp" usingBlock:^(SKNode *node, BOOL *stop) {
        if(node.position.x - node.frame.size.width > self.size.width){
            [node removeFromParent];
        }
    }];
    
    
    [_mainLayer enumerateChildNodesWithName:@"halo" usingBlock:^(SKNode *node, BOOL *stop) {
        if (node.position.y + node.frame.size.height < 0) {
            [node removeFromParent];
        }
    }];
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
}

@end
