//
//  DMDrawViewController.m
//  DrawMaster
//
//  Created by git on 16/6/28.
//  Copyright © 2016年 QuanGe. All rights reserved.
//

#import "DMDrawViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import "DMDrawView.h"
#import "DMBrushView.h"
#import "ISColorWheel.h"
#import <AVFoundation/AVAudioSession.h>
#import <MediaPlayer/MediaPlayer.h>
@interface DMDrawViewController ()<UICollectionViewDataSource,UICollectionViewDelegate>
@property (weak, nonatomic) IBOutlet UIButton *backBtn;
@property (weak, nonatomic) IBOutlet DMDrawView *drawView;
@property (nonatomic,readwrite,strong) MPVolumeView *volumeView;
@property (nonatomic,readwrite,assign) CGFloat lastVolumeValue;
@property (nonatomic,readwrite,assign) BOOL resetVolumeTag;
@property (weak, nonatomic) IBOutlet DMBrushView *brushView;

@property (weak, nonatomic) IBOutlet UIView *selectBrushBackGroundView;
@property (readwrite, nonatomic,strong) UIView *selectBrushBoxView;
@property (readwrite, nonatomic,strong) UIView *editBrushBoxView;
@property (readwrite, nonatomic,strong) MASConstraint*selectBrushBoxViewCenterY;
@property (readwrite, nonatomic,strong) MASConstraint*editBrushBoxViewCenterY;
@property (nonatomic,readwrite,strong) UICollectionView * collecttionView;
@property (nonatomic,readwrite,strong) ISColorWheel* editBrushColorView;
@property (nonatomic,readwrite,strong) NSMutableArray *brushColors;


@end

@implementation DMDrawViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //返回按钮相关
    self.backBtn.layer.backgroundColor= mRGBToColor(0xeeeeee).CGColor;
    self.backBtn.layer.cornerRadius = 22.5;
    self.backBtn.alpha = 0.8;
    @weakify(self)
    self.backBtn.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        @strongify(self)
        [self.navigationController popViewControllerAnimated:YES];
        return [RACSignal empty];
    }];
    
    // 设置允许摇一摇功能
    [UIApplication sharedApplication].applicationSupportsShakeToEdit = YES;
    // 并让自己成为第一响应者
    [self becomeFirstResponder];
    
    //音量键相关
    self.resetVolumeTag = NO;
    
    //读取保存的画笔相关信息
    NSString* brushWidth =  [[NSUserDefaults standardUserDefaults] objectForKey:@"DMBrushWidth"];
    if(brushWidth== nil)
    {
        brushWidth = @"3.0";
        [[NSUserDefaults standardUserDefaults] setObject:@"3.0" forKey:@"DMBrushWidth"];
    }
    NSData *brushColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"DMBrushColor"];
    if(brushColor == nil)
    {
        
        brushColor = [NSKeyedArchiver archivedDataWithRootObject:mRGBToColor(0xDF0526)];
        [[NSUserDefaults standardUserDefaults] setObject:brushColor forKey:@"DMBrushColor"];
    }
    NSMutableArray *customBrushColors = [[NSUserDefaults standardUserDefaults] objectForKey:@"DMCustomBrushColors"];
    if(customBrushColors == nil)
    {
        [[NSUserDefaults standardUserDefaults] setObject:[NSMutableArray array] forKey:@"DMCustomBrushColors"];
    }
   
    
    //画笔控件
    self.brushView.layer.cornerRadius = 22.5;
    self.brushView.clipsToBounds = YES;
    self.brushView.alpha = 0.8;
    [self.brushView updateRadius:22.5 BrushWidth:[brushWidth floatValue] BrushColor:(UIColor*)[NSKeyedUnarchiver unarchiveObjectWithData:brushColor]];
    [self.drawView updateBrushWidth:[brushWidth floatValue] BrushColor:(UIColor*)[NSKeyedUnarchiver unarchiveObjectWithData:brushColor]];
    [self.brushView addTarget:self action:@selector(openSelectBrush:) forControlEvents:UIControlEventTouchUpInside];
    
    
    //
    self.selectBrushBackGroundView.backgroundColor = mRGBAToColor(0xcccccc, 0.8);
    self.selectBrushBackGroundView.hidden = YES;
    self.selectBrushBackGroundView.alpha = 0;
    UIView * backGround = [[UIView alloc] init];
    {
        backGround.alpha = 0.1;
        [self.selectBrushBackGroundView addSubview:backGround];
        [backGround mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.bottom.right.top.mas_equalTo(0);
        }];
        UITapGestureRecognizer * tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openSelectBrush:)];
        [backGround addGestureRecognizer:tap];

    }
    
    CGFloat thescale = mIsPad?0.7:1.0;
    self.selectBrushBoxView = [[UIView alloc] init];
    {
        self.selectBrushBoxView.layer.cornerRadius = 5.0;
        self.selectBrushBoxView.layer.backgroundColor = [UIColor whiteColor].CGColor;
        [self.selectBrushBackGroundView addSubview:self.selectBrushBoxView];
        [self.selectBrushBoxView  mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.mas_equalTo((mScreenWidth-50)*thescale);
            make.height.mas_equalTo((mSelfViewHeight*2.0/3.0)*thescale);
            make.centerX.mas_equalTo(0);
            self.selectBrushBoxViewCenterY = make.centerY.mas_equalTo(0);
        }];
        UILabel * title = [[UILabel alloc] init];
        {
            title.text = @"请选择笔的颜色";
            title.font = [UIFont systemFontOfSize:13];
            title.textAlignment = NSTextAlignmentCenter;
            [self.selectBrushBoxView addSubview:title];
            [title mas_makeConstraints:^(MASConstraintMaker *make) {
                
                make.left.right.top.mas_equalTo(0);
                make.height.mas_equalTo(40);
                
            }];
        }
        UICollectionViewFlowLayout *copyLayout=[[UICollectionViewFlowLayout alloc] init];
        {
            copyLayout.minimumLineSpacing = 10;
            [copyLayout setScrollDirection:UICollectionViewScrollDirectionVertical];
            
            self.collecttionView = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:copyLayout];
            {
                [self.selectBrushBoxView addSubview:self.collecttionView];
                self.collecttionView.delegate = self;
                self.collecttionView.dataSource = self;
                self.collecttionView.backgroundColor = [UIColor whiteColor];
                [self.collecttionView mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.left.mas_equalTo(10);
                    make.bottom.mas_equalTo(-50);
                    make.right.mas_equalTo(-10);
                    make.top.mas_equalTo(40);
                }];
                
                [self.collecttionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:NSStringFromClass([UICollectionViewCell class])];
                [self.collecttionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"noData"];
               
                [self.collecttionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:NSStringFromClass([UICollectionReusableView class])];
                
            }
            
        }
        
        UIButton * colorEditBtn = [[UIButton alloc] init];
        {
            colorEditBtn.layer.borderWidth = 1.0;
            colorEditBtn.layer.cornerRadius = 3.0;
            colorEditBtn.layer.borderColor =mRGBToColor(0x333333).CGColor;
            [colorEditBtn setTitle:@"自定义" forState:UIControlStateNormal];
            [colorEditBtn setTitleColor:mRGBToColor(0x333333) forState:UIControlStateNormal];
            colorEditBtn.titleLabel.font = [UIFont systemFontOfSize:12];
            [self.selectBrushBoxView addSubview:colorEditBtn];
            [colorEditBtn mas_makeConstraints:^(MASConstraintMaker *make) {
                make.width.mas_equalTo(50);
                make.height.mas_equalTo(30);
                make.bottom.mas_equalTo(-5);
                make.centerX.mas_equalTo(0);
            }];
        }
        [colorEditBtn addTarget:self action:@selector(openEditColor:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    
    //
    self.editBrushBoxView = [[UIView alloc] init];
    {
        self.editBrushBoxView.layer.cornerRadius = 5.0;
        self.editBrushBoxView.layer.backgroundColor = [UIColor whiteColor].CGColor;
        [self.selectBrushBackGroundView addSubview:self.editBrushBoxView];
        [self.editBrushBoxView  mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.mas_equalTo((mScreenWidth-50)*thescale);
            make.height.mas_equalTo((mScreenWidth-50)*thescale);
            make.centerX.mas_equalTo(0);
            self.editBrushBoxViewCenterY = make.centerY.mas_equalTo(mScreenHeight);
        }];
        UILabel * title = [[UILabel alloc] init];
        {
            title.text = @"自定义笔的颜色";
            title.font = [UIFont systemFontOfSize:13];
            title.textAlignment = NSTextAlignmentCenter;
            [self.editBrushBoxView addSubview:title];
            [title mas_makeConstraints:^(MASConstraintMaker *make) {
                
                make.left.right.top.mas_equalTo(0);
                make.height.mas_equalTo(40);
                
            }];
        }
        
        self.editBrushColorView = [[ISColorWheel alloc] init];
        {
            [self.editBrushBoxView addSubview:self.editBrushColorView];
            [self.editBrushColorView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.width.height.mas_equalTo((mScreenWidth*2/3)*thescale);
                make.centerX.mas_equalTo(0);
                make.centerY.mas_equalTo(0);
            }];
        }
        
        UIButton * okBtn = [[UIButton alloc] init];
        {
            [self.editBrushBoxView addSubview:okBtn];
            [okBtn mas_makeConstraints:^(MASConstraintMaker *make) {
                okBtn.layer.borderWidth = 1.0;
                okBtn.layer.cornerRadius = 3.0;
                okBtn.layer.borderColor =mRGBToColor(0x333333).CGColor;
                [okBtn setTitle:@"完成" forState:UIControlStateNormal];
                [okBtn setTitleColor:mRGBToColor(0x333333) forState:UIControlStateNormal];
                okBtn.titleLabel.font = [UIFont systemFontOfSize:12];
                [self.editBrushBoxView addSubview:okBtn];
                [okBtn mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.width.mas_equalTo(50);
                    make.height.mas_equalTo(30);
                    make.bottom.mas_equalTo(-5);
                    make.right.mas_equalTo(-10);
                }];

                
            }];
            @weakify(self)
            okBtn.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
                @strongify(self)
                NSMutableArray *customBrushColors = [[NSUserDefaults standardUserDefaults] objectForKey:@"DMCustomBrushColors"];
                NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:self.editBrushColorView.currentColor];
                NSMutableArray *temp = [NSMutableArray arrayWithArray:customBrushColors];
                [temp addObject:colorData];
                [[NSUserDefaults standardUserDefaults] setObject:temp forKey:@"DMCustomBrushColors"];
                [self.collecttionView reloadData];
                [self openEditColor:nil];
                return [RACSignal empty];
            }];
            
        }
    }
    
    
    
    //
    self.brushColors = [NSMutableArray arrayWithObjects:@(0xDF0526),@(0xEC0B5F),@(0x9D25A9),@(0x6438A0),@(0x4052AE),
                        @(0x5A78F4),@(0x00AAF0),@(0x00BED2),@(0x009687),@(0x119B39),
                        @(0x87C35B),@(0xCADC57),@(0xFFEB5F),@(0xFFBF3E),@(0xFF512F),
                        @(0x73554B),@(0x9E9E00),@(0x5F7D8A),@(0xeeeeee),@(0xcccccc),
                        @(0x888888),@(0x555555),@(0x333333),@(0x111111),@(0x000000),nil];
    
}


- (void)openEditColor:(UIButton*)btn
{
    if(self.editBrushBoxView.tag == 0)
    {
        [UIView animateWithDuration:0.5 animations:^{
            self.selectBrushBoxViewCenterY.mas_equalTo(-mScreenHeight);
            self.editBrushBoxViewCenterY.mas_equalTo(0);
            [self.view layoutIfNeeded];
            
        }];
        self.editBrushBoxView.tag = 1;
    }
    else
    {
        [UIView animateWithDuration:0.5 animations:^{
            self.selectBrushBoxViewCenterY.mas_equalTo(0);
            self.editBrushBoxViewCenterY.mas_equalTo(mScreenHeight);
            [self.view layoutIfNeeded];
            
        }];
        self.editBrushBoxView.tag = 0;
    }
}

- (void)openSelectBrush:(DMBrushView*)btn
{
    if(self.brushView.tag == 0)
    {
        self.selectBrushBackGroundView.hidden = NO;
        [UIView animateWithDuration:0.5 animations:^{
            self.selectBrushBackGroundView.alpha = 1.0;
        }];
        
        self.brushView.tag = 1;
    }else
    {
        [UIView animateWithDuration:0.5 animations:^{
            self.selectBrushBackGroundView.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.selectBrushBackGroundView.hidden = YES;
        }];
        
        self.brushView.tag = 0;
    }
    NSLog(@"打开选择画笔的界面");
}

-(void) startTrackingVolume
{
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    
    if (!self.volumeView) {
        // put it somewhere outside the bounds of parent view
        self.volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-100, -100, 10, 0)];
        [self.volumeView sizeToFit];
    }
    
    if (!self.volumeView.superview) {
        [self.view addSubview:self.volumeView];
    }
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(volumeChanged:)
     name:@"AVSystemController_SystemVolumeDidChangeNotification"
     object:nil];
    
    UISlider* volumeViewSlider = nil;
    for (UIView *view in [self.volumeView subviews]){
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            volumeViewSlider = (UISlider*)view;
            break;
        }
    }
    self.lastVolumeValue = volumeViewSlider.value;

}

- (void)volumeChanged:(NSNotification *)notification
{
    if(self.resetVolumeTag)
    {
        self.resetVolumeTag = NO;
        return;
    }
    NSDictionary* info = [notification userInfo];
    NSNumber* e = info[@"AVSystemController_AudioVolumeNotificationParameter"];
    
   
    [ self changeBrushWidthWithUP:self.lastVolumeValue <e.floatValue];
//    if(self.lastVolumeValue >e.floatValue)
//    {
//        NSLog(@"画笔变细");
//        
//    }
//    else
//    {
//        NSLog(@"画笔变粗");
//    }
    [self resetVolume];
   
    
}

- (void)resetVolume
{
    self.resetVolumeTag = YES;
    UISlider* volumeViewSlider = nil;
    for (UIView *view in [self.volumeView subviews]){
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            volumeViewSlider = (UISlider*)view;
            break;
        }
    }
    
    [volumeViewSlider setValue:self.lastVolumeValue  animated:NO];
}
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self startTrackingVolume];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/



#pragma mark - 摇一摇相关方法
// 摇一摇开始摇动
- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    NSLog(@"开始摇动");
    return;
}

// 摇一摇取消摇动
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    NSLog(@"取消摇动");
    return;
}

// 摇一摇摇动结束
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (event.subtype == UIEventSubtypeMotionShake) { // 判断是否是摇动结束
        NSLog(@"摇动结束");
        [self shakeshake];
        [self.drawView shakeToClear];
        NSString* brushWidth =  [[NSUserDefaults standardUserDefaults] objectForKey:@"DMBrushWidth"];
        NSData *brushColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"DMBrushColor"];
        [self.drawView updateBrushWidth:[brushWidth floatValue] BrushColor:(UIColor*)[NSKeyedUnarchiver unarchiveObjectWithData:brushColor]];
        
    }
    return;
}

//  摇动结束后执行震动
- (void)shakeshake {
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

- (void)changeBrushWidthWithUP:(BOOL)up
{
    NSString* brushWidth =  [[NSUserDefaults standardUserDefaults] objectForKey:@"DMBrushWidth"];
    if(up)
    {
        if([brushWidth floatValue]< 8.0)
            brushWidth = @([brushWidth floatValue]+0.5).stringValue;
    }
    else
    {
        if([brushWidth floatValue]>=1.0)
            brushWidth = @([brushWidth floatValue]-0.5).stringValue;
    }
    NSData *brushColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"DMBrushColor"];
  
    [self.brushView updateRadius:22.5 BrushWidth:[brushWidth floatValue] BrushColor:(UIColor*)[NSKeyedUnarchiver unarchiveObjectWithData:brushColor]];
    [self.drawView updateBrushWidth:[brushWidth floatValue] BrushColor:(UIColor*)[NSKeyedUnarchiver unarchiveObjectWithData:brushColor]];
    [[NSUserDefaults standardUserDefaults] setObject:brushWidth forKey:@"DMBrushWidth"];
    
}


#pragma mark --UICollectionView回调
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSMutableArray *customBrushColors = [[NSUserDefaults standardUserDefaults] objectForKey:@"DMCustomBrushColors"];
    if(section ==1)
        return self.brushColors.count;
    else
        return customBrushColors.count == 0?1:customBrushColors.count;
    //return 20;
}

- (NSInteger)numberOfSectionsInCollectionView: (UICollectionView *)collectionView {
    
    return 2;
    
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *customBrushColors = [[NSUserDefaults standardUserDefaults] objectForKey:@"DMCustomBrushColors"];
    if(indexPath.section == 0&&customBrushColors.count == 0)
    {
        UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"noData" forIndexPath:indexPath];
        if(cell.contentView.subviews.count == 0)
        {
            UILabel * sub = [[UILabel alloc] init];
            [cell.contentView addSubview:sub];
            sub.text = @"请点击自定义按钮添加自定义颜色";
            sub.font = [UIFont systemFontOfSize:13];
            sub.textColor = mRGBToColor(0xcccccc);
            sub.textAlignment = NSTextAlignmentCenter;
          
            [sub mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.right.top.bottom.mas_equalTo(0);
            }];
        }
        return cell;
    }
    
    UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:NSStringFromClass([UICollectionViewCell class]) forIndexPath:indexPath];
    if(cell.contentView.subviews.count == 0)
    {
        UIView * sub = [[UIView alloc] init];
        [cell.contentView addSubview:sub];
        sub.tag = 11;
        [sub mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.top.bottom.mas_equalTo(0);
        }];
        
        
    }
    
    
    
    UIView * sub = [cell.contentView viewWithTag:11];
    UILongPressGestureRecognizer *lg = [[UILongPressGestureRecognizer alloc] init];
    [lg.rac_gestureSignal subscribeNext:^(UILongPressGestureRecognizer *lgx) {
        if(lgx.state == UIGestureRecognizerStateBegan &&indexPath.section == 0)
        {
            NSLog(@"删除第%@个自定义的颜色",@(indexPath.row).stringValue);
            [UIAlertView qgocc_showWithTitle:@"删除自定义颜色"
                                     message:@"确定要删除么？"
                           cancelButtonTitle:@"考虑考虑"
                           otherButtonTitles:@[@"删除"]
                                    tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                        if (buttonIndex == [alertView cancelButtonIndex]) {
                                            [alertView dismissWithClickedButtonIndex:0 animated:YES];
                                        } else if (buttonIndex == 1) {
                                            NSMutableArray *customBrushColors = [[NSUserDefaults standardUserDefaults] objectForKey:@"DMCustomBrushColors"];
                                            NSMutableArray *temp = [NSMutableArray arrayWithArray:customBrushColors];
                                            [temp removeObjectAtIndex:indexPath.row];
                                            [[NSUserDefaults standardUserDefaults] setObject:temp forKey:@"DMCustomBrushColors"];
                                            [cv reloadData];
                                        }
                                    }];
            
        }
    }];
    [sub addGestureRecognizer:lg];
    if(indexPath.section ==1)
        sub.layer.backgroundColor = mRGBToColor([[self.brushColors  objectAtIndex:indexPath.row] integerValue]).CGColor;
    else
        sub.layer.backgroundColor = ((UIColor*)[NSKeyedUnarchiver unarchiveObjectWithData:[customBrushColors objectAtIndex:indexPath.row]]).CGColor;
    sub.layer.cornerRadius = cv.frame.size.width/12;
    return cell;
}



- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    NSMutableArray *customBrushColors = [[NSUserDefaults standardUserDefaults] objectForKey:@"DMCustomBrushColors"];
    if(indexPath.section == 0&&customBrushColors.count == 0)
    {
        return CGSizeMake(mScreenWidth-20, 30);
    }
    return CGSizeMake(collectionView.frame.size.width/6, collectionView.frame.size.width/6);
}

- (UIEdgeInsets)collectionView:
(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(0, 5 , 0, 5);
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;
{
    if([kind isEqualToString:UICollectionElementKindSectionHeader])
    {
        
    UICollectionReusableView * header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:NSStringFromClass([UICollectionReusableView class]) forIndexPath:indexPath];
        
            if(header.subviews.count == 0)
            {
                
                CGFloat redRadius = 8;
                
                UILabel *title = [[UILabel alloc] init];
                title.font = [UIFont systemFontOfSize:16];
                title.textColor = kBlackColor;
                title.tag = 100;
                [header addSubview:title];
                [title mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.left.mas_equalTo(2*redRadius+2);
                    make.top.mas_equalTo(0);
                    make.bottom.mas_equalTo(0);
                    make.right.mas_equalTo(0);
                }];
                
                
                UIView *red = [[UIView alloc] init];
                red.layer.backgroundColor = [UIColor redColor].CGColor;
                red.layer.cornerRadius = redRadius/2;
                [header addSubview:red];
                [red mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.left.equalTo(header).with.offset(2);
                    make.width.mas_equalTo(redRadius);
                    make.height.mas_equalTo(redRadius);
                    make.centerY.equalTo(header);
                }];
                
                
                
                
            }
        
            if([header viewWithTag:100])
            {
                UILabel *title = (UILabel *)[header viewWithTag:100];
                switch (indexPath.section) {
                    case 0:
                        title.text = @"自定义";
                        break;
                    case 1:
                        title.text = @"标准色";
                        break;
                    
                    default:
                        break;
                }
                //title.text = indexPath.section == 0 ?@"最新":@"最热";
                
            }
            
            return header;
            
        
    }
    else
        return nil;
    
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    return CGSizeMake(mScreenWidth, 30);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
{
    NSLog(@"选取颜色");
    NSMutableArray *customBrushColors = [[NSUserDefaults standardUserDefaults] objectForKey:@"DMCustomBrushColors"];
    [self openSelectBrush:nil];
    UIColor * tempColor = nil;
    if(indexPath.section ==1)
        tempColor = mRGBToColor([[self.brushColors  objectAtIndex:indexPath.row] integerValue]);
    else
        tempColor = ((UIColor*)[NSKeyedUnarchiver unarchiveObjectWithData:[customBrushColors objectAtIndex:indexPath.row]]);
    NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:tempColor];
    [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DMBrushColor"];
    
    NSString* brushWidth =  [[NSUserDefaults standardUserDefaults] objectForKey:@"DMBrushWidth"];
    [self.brushView updateRadius:22.5 BrushWidth:[brushWidth floatValue] BrushColor:tempColor];
    [self.drawView updateBrushWidth:[brushWidth floatValue] BrushColor:tempColor];
    
}



- (void)colorWheelDidChangeColor:(ISColorWheel *)colorWheel
{
    //NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:colorWheel.currentColor];
    /*
     const CGFloat  *components = CGColorGetComponents(pColor.CGColor);
     NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
     [prefs setFloat:components[0]  forKey:@"cr"];
     [prefs setFloat:components[1]  forKey:@"cg"];
     [prefs setFloat:components[2]  forKey:@"cb"];
     [prefs setFloat:components[3]  forKey:@"ca"];
     */
    
   
}

@end