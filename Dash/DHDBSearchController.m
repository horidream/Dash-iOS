//
//  Copyright (C) 2016  Kapeli
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "DHDBSearchController.h"
#import "DHBrowserTableViewCell.h"
#import "DHDBResult.h"
#import "DHDocsetManager.h"
#import "DHDocsetBrowser.h"
#import "DHNestedViewController.h"

@implementation DHDBSearchController

+ (DHDBSearchController *)searchControllerWithDocsets:(NSArray *)docsets typeLimit:(NSString *)typeLimit viewController:(UITableViewController *)viewController;
{
    DHDBSearchController *controller = [[DHDBSearchController alloc] init];
    controller.docsets = docsets;
    controller.typeLimit = typeLimit;
    controller.originalController = viewController;

    UISearchController *ctrl = [[UISearchController alloc] initWithSearchResultsController:controller];
    ctrl.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    controller.searchController = ctrl;
    ctrl.delegate = controller;
    ctrl.searchResultsUpdater = controller;

    [[NSNotificationCenter defaultCenter] addObserver:controller selector:@selector(traitCollectionDidChange:) name:DHWindowChangedTraitCollection object:nil];

    // Hooks
    if (@available(iOS 11.0, *)) {
        controller.originalController.navigationItem.searchController = ctrl;
        controller.originalController.navigationItem.hidesSearchBarWhenScrolling = NO;
//        CGFloat topbarHeight = ([UIApplication sharedApplication].statusBarFrame.size.height +
//        (viewController.navigationController.navigationBar.frame.size.height ?: 0.0));
        [controller.tableView setContentInset:UIEdgeInsetsMake(108, 0, 0, 0)];
    } else {
        controller.tableView.tableHeaderView = ctrl.searchBar;
    }
    return controller;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.tableView registerNib:[UINib nibWithNibName:@"DHBrowserCell" bundle:nil] forCellReuseIdentifier:@"DHBrowserCell"];
    [self.tableView registerNib:[UINib nibWithNibName:@"DHLoadingCell" bundle:nil] forCellReuseIdentifier:@"DHLoadingCell"];
}

- (void)viewWillAppear
{
    if(self.searchController.active)
    {
        
    }
}

- (void)viewDidAppear
{
    if(self.searchController.active)
    {

    }
}

- (void)viewWillDisappear
{
    if(self.searchController.active)
    {
    
    }
}

- (void)viewDidDisappear
{
    if(self.searchController.active)
    {

    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    if(self.results.count && !self.loading)
    {
        [self.tableView reloadData];
    }
}

-(void) updateSearchResultsForSearchController:(UISearchController *)searchController {

    BOOL loading = searchController.isActive;

    if (loading) {
        self.tableView.allowsSelection = YES;
        [self.tableView reloadData];

        self.nextResults = [[NSMutableArray alloc] init];
        NSString *searchString = [searchController.searchBar.text stringByRemovingWhitespaces];
        if (searchString.length < 1) {
            return;
        }
        [self.searcher cancelSearch];
        self.searcher = [DHDBSearcher searcherWithDocsets:(self.docsets) ? self.docsets : [(id)self.originalController shownDocsets] query:searchString limitToType:self.typeLimit delegate:self];
    }
    self.loading = loading;
}

- (void)willPresentSearchController:(UISearchController *)searchController {
    if(isIOS11)
    {
        if(@available(iOS 11.0, *))
        {
            self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
    }
}
- (void)didPresentSearchController:(UISearchController *)searchController {
    self.viewControllerTitle = self.navigationItem.title;
    self.navigationItem.title = @"Search";
}

- (void)willDismissSearchController:(UISearchController *)searchController {
    self.navigationItem.title = self.viewControllerTitle;
    [self.searcher cancelSearch];
    self.searcher = nil;

}

- (void)searcher:(DHDBSearcher *)searcher foundResults:(NSArray *)results hasMore:(BOOL)hasMore
{
    if(searcher == self.searcher)
    {
        NSInteger previousSelection = self.tableView.indexPathForSelectedRow.row;
        BOOL isFirst = self.nextResults.count == 0;
        self.loading = NO;
        self.tableView.allowsSelection = YES;
        [self.nextResults addObjectsFromArray:results];
        self.results = self.nextResults;
        [self.tableView reloadData];
        if(isFirst && isRegularHorizontalClass && self.nextResults.count)
        {
            [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
            DHDBResult *firstResult = self.results[0];
            [[DHDBResultSorter sharedSorter] resultWasSelected:firstResult inTableView:self.tableView];
            [[DHWebViewController sharedWebViewController] loadResult:firstResult];
        }
        else if(isRegularHorizontalClass && !isFirst && self.results.count)
        {
            [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:previousSelection inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
        if(!hasMore)
        {
            self.nextResults = nil;
        }
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"DHNestedSegue"])
    {
        DHNestedViewController *nestedController = [segue destinationViewController];
        DHDBResult *result = self.results[self.tableView.indexPathForSelectedRow.row];
        nestedController.result = result;
    }
    else if([[segue identifier] isEqualToString:@"DHSearchWebViewSegue"])
    {
        DHWebViewController *webViewController = [segue destinationViewController];
        DHDBResult *result = self.results[self.tableView.indexPathForSelectedRow.row];
        webViewController.result = result;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(tableView.indexPathForSelectedRow.row < self.results.count)
    {
        DHDBResult *result = self.results[tableView.indexPathForSelectedRow.row];
        if(result.similarResults.count)
        {
            if(isRegularHorizontalClass)
            {
                [[DHWebViewController sharedWebViewController] loadResult:[result activeResult]];
            }
            [self.originalController performSegueWithIdentifier:@"DHNestedSegue" sender:self];
        }
        else
        {
            [[DHDBResultSorter sharedSorter] resultWasSelected:result inTableView:tableView];
            if(isRegularHorizontalClass)
            {
                [[DHWebViewController sharedWebViewController] loadResult:result];
                UIBarButtonItem *btn = [[DHWebViewController sharedWebViewController] toggleSplitViewButton];
                [btn setImage:[UIImage imageNamed:@"collapse"]];
                [btn.target performSelector:btn.action withObject:nil afterDelay:0];
            }
            else
            {
                [[DHWebViewController sharedWebViewController] loadResult:result];
                [self.originalController performSegueWithIdentifier:@"DHSearchWebViewSegue" sender:self];
                UIBarButtonItem *btn = [[DHWebViewController sharedWebViewController] toggleSplitViewButton];
                [btn setImage:[UIImage imageNamed:@"collapse"]];
                [btn.target performSelector:btn.action withObject:nil afterDelay:0];
            }
        }
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(self.loading)
    {
        return 3;
    }
    return self.results.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(self.loading)
    {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DHLoadingCell" forIndexPath:indexPath];
        cell.userInteractionEnabled = NO;
        if(indexPath.row == 2)
        {
            NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
            [paragraph setAlignment:NSTextAlignmentCenter];
            UIFont *font = [UIFont boldSystemFontOfSize:20];
            cell.textLabel.attributedText = [[NSAttributedString alloc] initWithString:@"Searching..." attributes:@{NSParagraphStyleAttributeName : paragraph, NSForegroundColorAttributeName: [UIColor colorWithWhite:0.8 alpha:1], NSFontAttributeName: font}];
        }
        else
        {
            cell.textLabel.text = @"";
        }
        return cell;
    }
    DHBrowserTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DHBrowserCell" forIndexPath:indexPath];

    DHDBResult *result = (indexPath.row) < self.results.count ? self.results[indexPath.row] : nil;
    [cell makeEntryCell];
    cell.textLabel.attributedText = nil;
    cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:16];
    cell.textLabel.text = result.name;
    cell.typeImageView.image = result.typeImage;
    cell.platformImageView.image = result.platformImage;
    [self highlightCell:cell result:result];
    [cell.titleLabel setRightDetailText:(result.similarResults.count) ? [NSString stringWithFormat:@"%ld", (unsigned long)result.similarResults.count+1] : @"" adjustMainWidth:YES];
    cell.accessoryType = (result.similarResults.count || !isRegularHorizontalClass) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    return cell;
}

- (void)highlightCell:(DHBrowserTableViewCell *)cell result:(DHDBResult *)result
{
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithAttributedString:cell.textLabel.attributedText];
    BOOL didAddAttributes = NO;
    for(NSString *key in [DHDBResult highlightDictionary])
    {
        [string removeAttribute:key range:NSMakeRange(0, string.length)];
    }
    for(NSValue *highlightRangeValue in result.highlightRanges)
    {
        NSRange highlightRange = [highlightRangeValue rangeValue];
        [string addAttributes:[DHDBResult highlightDictionary] range:highlightRange];
        didAddAttributes = YES;
    }
    if(didAddAttributes)
    {
        cell.textLabel.attributedText = string;
    }
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [coder encodeBool:self.searchController.isActive forKey:@"searchIsActive"];
    if(self.searchController.isActive)
    {
        [coder encodeObject:[self.searchController.searchBar text] forKey:@"searchBarText"];
        if(self.results)
        {
            [coder encodeObject:self.results forKey:@"searchResults"];
        }
        NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
        if(selectedIndexPath)
        {
            [coder encodeObject:selectedIndexPath forKey:@"selectedIndexPath"];
        }
        BOOL isFirstResponder = [self.searchController.searchBar isFirstResponder];
        [coder encodeBool:isFirstResponder forKey:@"isFirstResponder"];
        [coder encodeCGPoint:self.tableView.contentOffset forKey:@"scrollPoint"];
    }
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    BOOL isActive = [coder decodeBoolForKey:@"searchIsActive"];
    if(isActive)
    {
        self.isRestoring = YES;
        self.results = [coder decodeObjectForKey:@"searchResults"];
        NSString *searchBarText = [coder decodeObjectForKey:@"searchBarText"];
        NSIndexPath *selectedIndexPath = [coder decodeObjectForKey:@"selectedIndexPath"];
        BOOL isFirstResponder = [coder decodeBoolForKey:@"isFirstResponder"];
        CGPoint scrollPoint = [coder decodeCGPointForKey:@"scrollPoint"];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((isRegularHorizontalClass) ? 0.5 * NSEC_PER_SEC : 0)), dispatch_get_main_queue(), ^{
            self.searchController.active = YES;
            if(searchBarText)
            {
                [self.searchController.searchBar setText:searchBarText];
            }
            if(selectedIndexPath)
            {
                [self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
            if(isFirstResponder)
            {
                [self.searchController.searchBar becomeFirstResponder];
            }
            self.tableView.contentOffset = scrollPoint;
            self.isRestoring = NO;
        });
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.searcher cancelSearch];
}

@end
