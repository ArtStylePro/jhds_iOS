//
//  DMMineNewsViewController.m
//  DrawMaster
//
//  Created by git on 16/7/5.
//  Copyright © 2016年 QuanGe. All rights reserved.
//

#import "DMMineNewsViewController.h"
#import "DMNewsViewModel.h"
#import "DMWebViewController.h"
@interface DMMineNewsViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic,readwrite,strong) UITableView * tableview;
@property (nonatomic,readwrite,strong) DMNewsViewModel * viewModel;
@end

@implementation DMMineNewsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.titleLabel.text = @"官方公告";
    self.viewModel = [[DMNewsViewModel alloc] init];
    self.tableview = [[UITableView alloc] init];
    {
        self.tableview.delegate = self;
        self.tableview.dataSource = self;
        self.tableview.pullType = SVPullTypeVisibleLogo;
        [self.view addSubview:self.tableview];
        [self.tableview mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.bottom.mas_equalTo(0);
            make.top.mas_equalTo(65);
        }];
        @weakify(self)
        [self.tableview addPullToRefreshWithActionHandler:^{
            @strongify(self)
            [[self.viewModel fetchData] subscribeNext:^(NSArray* x) {
                
                [self.tableview.pullToRefreshView stopAnimating];
                if(x.count == 0)
                    [self.tableview showNoNataViewWithMessage:@"这里还没有内容哦" imageName:@"icon_my_last"];
                else
                    [self.tableview reloadData];
            } error:^(NSError *error) {
                [self.tableview.pullToRefreshView stopAnimating];
                [self.tableview showNoNataViewWithMessage:@"获取数据，请稍候再试" imageName:@"icon_my_last"];
            }];
        }];
        [self.tableview registerClass:[UITableViewCell class] forCellReuseIdentifier:NSStringFromClass([UITableViewCell class])];
        
        [self.tableview.pullToRefreshView setTitle:@"下拉更新" forState:SVPullToRefreshStateStopped];
        [self.tableview.pullToRefreshView setTitle:@"释放更新" forState:SVPullToRefreshStateTriggered];
        [self.tableview.pullToRefreshView setTitle:@"卖力加载中" forState:SVPullToRefreshStateLoading];
        
        [self.tableview triggerPullToRefresh];
        self.tableview.tableFooterView = [[UIView alloc] init];
    }
    
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
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.viewModel newsNum];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([UITableViewCell class])];
    cell.textLabel.text = [self.viewModel newsTitleWithRow:indexPath.row];
    cell.textLabel.font = [UIFont systemFontOfSize:14];
    cell.textLabel.textColor = mRGBToColor(0x666666);
    
    cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"list_arrow"]];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    return 55;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    DMWebViewController *modal =  [[DMWebViewController alloc] init];
    modal.detailUrl = [self.viewModel newsDetailWithRow:indexPath.row];
    modal.detailTitle = [self.viewModel newsTitleWithRow:indexPath.row];
    modal.canShare = NO;
    [self.navigationController pushViewController:modal animated:YES];

}

@end
