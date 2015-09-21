//
//  MDMFetchedResultsTableDataSource.m
//
//  Copyright (c) 2014 Matthew Morey.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "MDMFetchedResultsTableDataSource.h"
#import "MDMCoreDataMacros.h"

@interface MDMFetchedResultsTableDataSource ()

@property (nonatomic, weak) UITableView *tableView;
@property (nonatomic, strong) NSMutableIndexSet *sectionsBeingAdded;
@property (nonatomic, strong) NSMutableIndexSet *sectionsBeingRemoved;

@end

@implementation MDMFetchedResultsTableDataSource

#pragma mark - Lifecycle

- (id)initWithTableView:(UITableView *)tableView
fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController {
    
    self = [super init];
    if (self) {
        
        _tableView = tableView;
        _fetchedResultsController = fetchedResultsController;
        [self setupFetchedResultsController:fetchedResultsController];
    }
    
    return self;
}

#pragma mark - Private Methods

- (void)setupFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController {
    
    fetchedResultsController.delegate = self;
    BOOL fetchSuccess = [fetchedResultsController performFetch:NULL];
    ZAssert(fetchSuccess, @"Fetch request does not include sort descriptor that uses the section name.");
    [self.tableView reloadData];
}

- (id)itemAtIndexPath:(NSIndexPath *)path {
    
    return [self.fetchedResultsController objectAtIndexPath:path];
}

#pragma mark - Public Setters

- (void)setFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController {
    
    if (_fetchedResultsController != fetchedResultsController) {
        
        _fetchedResultsController = fetchedResultsController;
        [self setupFetchedResultsController:fetchedResultsController];
    }
}

- (void)setPaused:(BOOL)paused {
    
    _paused = paused;
    if (paused) {
        self.fetchedResultsController.delegate = nil;
    } else {
        self.fetchedResultsController.delegate = self;
        [self.fetchedResultsController performFetch:NULL];
        [self.tableView reloadData];
    }
}

#pragma mark - Public Methods

- (id)selectedItem {
    
    NSIndexPath *path = [self.tableView indexPathForSelectedRow];
    
    return path ? [self itemAtIndexPath:path] : nil;
}

- (NSUInteger)numberOfRowsInSection:(NSUInteger)section {
    
    if (section < [self.fetchedResultsController.sections count]) {
        
        return [self.fetchedResultsController.sections[section] numberOfObjects];
    }
    
    return 0; // If section doesn't exist return 0
}

- (NSUInteger)numberOfRowsInAllSections {
    
    NSUInteger totalRows = 0;
    NSUInteger totalSections = [self.fetchedResultsController.sections count];
    
    for (NSUInteger section = 0; section < totalSections; section++) {
        totalRows = totalRows + [self numberOfRowsInSection:section];
    }
    
    return totalRows;
}

- (NSIndexPath *)indexPathForObject:(id)object {
    
    return [self.fetchedResultsController indexPathForObject:object];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return self.fetchedResultsController.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self numberOfRowsInSection:(NSUInteger)section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    id object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    id cell = [tableView dequeueReusableCellWithIdentifier:self.reuseIdentifier forIndexPath:indexPath];
    [self.delegate dataSource:self configureCell:cell withObject:object];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    switch (editingStyle) {
        case UITableViewCellEditingStyleDelete: {
            [self.delegate dataSource:self deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]
                          atIndexPath:indexPath];
            
            break;
        }
            
        default:
            ALog(@"Missing UITableViewCellEditingStyle case");
            
            break;
    }
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    
    [self.tableView endUpdates];
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    
    self.sectionsBeingAdded = [NSMutableIndexSet indexSet];
    self.sectionsBeingRemoved = [NSMutableIndexSet indexSet];
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type {
    
    switch (type) {
        case NSFetchedResultsChangeInsert:
            [self.sectionsBeingAdded addIndex:sectionIndex];
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationNone];
            
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.sectionsBeingRemoved addIndex:sectionIndex];
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationNone];
            
            break;
            
        default:
            ALog(@"Missing NSFechedResultsChange case");
            
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    
    switch (type) {
        case NSFetchedResultsChangeUpdate:
            // SDK 9.0 running on iOS 8.3 bug:
            // NSFetchedResultsController may not even contain this indexPath anymore
            if(![self.sectionsBeingRemoved containsIndex:indexPath.section] && ![self.sectionsBeingAdded containsIndex:indexPath.section]) {
                // iOS 8.3 sends update before delete therefore we cannot use reload
                // fixes crash but cell may not update reliably.
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                [self.delegate dataSource:self configureCell:cell withObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
            }
            
            break;
            
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath]
                                  withRowAnimation:UITableViewRowAnimationNone];
            
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                                  withRowAnimation:UITableViewRowAnimationNone];
            
            break;
            
        case NSFetchedResultsChangeMove:
            
            // SDK 9.0 running on iOS 8.3 bug:
            // Sends the same index path twice instead of delete
            if(![indexPath isEqual:newIndexPath]) {
                [self.tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.tableView insertRowsAtIndexPaths:@[ newIndexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if([self.sectionsBeingAdded containsIndex:indexPath.section]) {
                // SDK 9.0 running on iOS 8.3 bug:
                // Moving first item from section 0 (which becomes section 1 later) to section 0
                // Really the only way is to delete and insert the same index path...
                [self.tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.tableView insertRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else if([self.sectionsBeingRemoved containsIndex:indexPath.section]) {
                // SDK 9.0 running on iOS 8.3 bug:
                // Same index path reported after section was removed
                // we can ignore item deletion here because the whole section was removed anyway
                [self.tableView insertRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            
            break;
        default:
            ALog(@"Missing NSFechedResultsChange case");
            
            break;
    }
}

- (BOOL)shouldMakeMoveForMovedObjectFromIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    
    return !([self.sectionsBeingRemoved containsIndex:fromIndexPath.section] || [self.sectionsBeingAdded containsIndex:toIndexPath.section]);
}

@end
