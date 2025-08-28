import 'dart:math';
import 'package:flutter/foundation.dart';

class PaginatedList<T> with ChangeNotifier {
  // Factory constructor for synchronous list creation
  factory PaginatedList(List<T> items, {int pageSize = 10, int? randomSeed}) {
    return PaginatedList._internal(
      items: items,
      pageSize: pageSize,
      randomSeed: randomSeed,
    );
  }

  // Factory constructor for async list creation
  factory PaginatedList.fromAsync(
    Future<List<T>> itemsFuture, {
    int pageSize = 10,
    int? randomSeed,
  }) {
    return PaginatedList._internal(
      itemsFuture: itemsFuture,
      pageSize: pageSize,
      randomSeed: randomSeed,
    );
  }

  // Private constructor for internal use
  PaginatedList._internal({
    required int pageSize,
    required int? randomSeed,
    Future<List<T>>? itemsFuture,
    List<T>? items,
  }) : _pageSize = pageSize,
       _random = randomSeed != null ? Random(randomSeed) : Random() {
    if (items != null) {
      // Synchronous initialization
      _allItems.addAll(items);
      _initialize();
      _loadFirstPage();
      _isLoading = false;
    } else if (itemsFuture != null) {
      // Asynchronous initialization
      _isLoading = true;
      _initializationFuture = _loadAsyncItems(itemsFuture);
    }
  }

  final List<T> _allItems = [];
  final Random _random;
  final int _pageSize;

  // Track selected indices and navigation history
  final Set<int> _selectedIndices = {};
  final List<List<int>> _pageHistory = [];
  int _currentPageIndex = -1;

  // Async loading state
  Future<void>? _initializationFuture;
  bool _isLoading = true;
  Object? _loadingError;

  Future<List<dynamic>> updateItems(Future<List<T>> itemsFuture) async {
    await _loadAsyncItems(itemsFuture);
    return getCurrentPage();
  }

  // Load items asynchronously
  Future<void> _loadAsyncItems(Future<List<T>> itemsFuture) async {
    try {
      _isLoading = true;
      _loadingError = null;
      notifyListeners();

      final items = await itemsFuture;
      _allItems.addAll(items);
      _initialize();
      _loadFirstPage();
      _isLoading = false;
      reset();
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _loadingError = error;
      reset();
      notifyListeners();
      rethrow;
    }
  }

  void _initialize() {
    final indices = List.generate(_allItems.length, (index) => index)
      ..shuffle(_random);
    _selectedIndices.addAll(indices);
  }

  // Add this private method
  Future<void> _ensureInitialized() async {
    if (_isLoading && _initializationFuture != null) {
      await _initializationFuture;
    }
  }

  void _loadFirstPage() {
    if (_selectedIndices.isEmpty) {
      _pageHistory.add([]);
      _currentPageIndex = 0;
      return;
    }

    final availableIndices = _selectedIndices.toList();
    final itemsToTake = min(_pageSize, availableIndices.length);
    final indicesForPage = availableIndices.take(itemsToTake).toList();

    _selectedIndices.removeAll(indicesForPage);
    _pageHistory.add(indicesForPage);
    _currentPageIndex = 0;
  }

  // Get the next page of random items
  List<T> getNextPage() {
    if (_isLoading) throw StateError('Cannot paginate while loading');
    if (_selectedIndices.isEmpty) return [];

    if (_currentPageIndex < _pageHistory.length - 1) {
      _pageHistory.removeRange(_currentPageIndex + 1, _pageHistory.length);
    }

    final availableIndices = _selectedIndices.toList();
    final itemsToTake = min(_pageSize, availableIndices.length);
    final indicesForPage = availableIndices.take(itemsToTake).toList();

    _selectedIndices.removeAll(indicesForPage);
    _pageHistory.add(indicesForPage);
    _currentPageIndex = _pageHistory.length - 1;

    notifyListeners();
    return indicesForPage.map((index) => _allItems[index]).toList();
  }

  // Get the next page of random items
  Future<List<T>> getNextPageAsync() async {
    await _ensureInitialized();
    return getNextPage();
  }

  // Get the previous page
  List<T> getPreviousPage() {
    if (_isLoading) throw StateError('Cannot paginate while loading');
    if (_currentPageIndex <= 0) return [];

    _currentPageIndex--;
    final previousPageIndices = _pageHistory[_currentPageIndex];
    _selectedIndices.addAll(previousPageIndices);

    notifyListeners();
    return previousPageIndices.map((index) => _allItems[index]).toList();
  }

  // Get the previous page
  Future<List<T>> getPreviousPageAsync() async {
    await _ensureInitialized();
    return getPreviousPage();
  }

  // Get the current page
  List<T> getCurrentPage() {
    if (_isLoading) return [];
    if (_currentPageIndex < 0 || _currentPageIndex >= _pageHistory.length) {
      return [];
    }
    return _pageHistory[_currentPageIndex]
        .map((index) => _allItems[index])
        .toList();
  }

  // Get the current page
  Future<List<T>> getCurrentPageAsync() async {
    await _ensureInitialized();
    return getCurrentPage();
  }

  // Jump to a specific page
  List<T> goToPage(int pageNumber) {
    if (_isLoading) throw StateError('Cannot paginate while loading');
    if (pageNumber < 1 || pageNumber > totalPages) {
      throw ArgumentError(
        'Page number $pageNumber is out of range (1-$totalPages)',
      );
    }

    final targetIndex = pageNumber - 1;

    if (targetIndex >= _pageHistory.length) {
      while (_currentPageIndex < targetIndex && hasNextPage) {
        getNextPage();
      }
      return getCurrentPage();
    }

    if (targetIndex > _currentPageIndex) {
      while (_currentPageIndex < targetIndex) {
        getNextPage();
      }
    } else if (targetIndex < _currentPageIndex) {
      while (_currentPageIndex > targetIndex) {
        getPreviousPage();
      }
    }

    return getCurrentPage();
  }

  // Jump to a specific page
  Future<List<T>> goToPageAsync(int pageNumber) async {
    await _ensureInitialized();
    return goToPage(pageNumber);
  }

  // Reset the paginator
  void reset() {
    if (_isLoading) throw StateError('Cannot reset while loading');

    _selectedIndices.clear();
    _pageHistory.clear();
    _currentPageIndex = -1;
    _initialize();
    _loadFirstPage();
    notifyListeners();
  }

  // Refresh with new data
  Future<void> refresh([Future<List<T>>? newItemsFuture]) async {
    if (newItemsFuture != null) {
      // Load new items from provided future
      await _loadAsyncItems(newItemsFuture);
    } else {
      // Re-initialize with current items
      _selectedIndices.clear();
      _pageHistory.clear();
      _currentPageIndex = -1;
      _initialize();
      _loadFirstPage();
      notifyListeners();
    }
  }

  // Properties
  bool get hasNextPage => !_isLoading && _selectedIndices.isNotEmpty;
  bool get hasPreviousPage => !_isLoading && _currentPageIndex > 0;
  int get currentPageNumber => _isLoading ? 0 : _currentPageIndex + 1;
  int get totalPages =>
      _isLoading
          ? 0
          : _pageHistory.length + (_selectedIndices.length / _pageSize).ceil();
  int get pagesViewed => _isLoading ? 0 : _pageHistory.length;
  int get totalItems => _isLoading ? 0 : _allItems.length;
  int get remainingItems => _isLoading ? 0 : _selectedIndices.length;

  double get progress {
    if (_isLoading || _allItems.isEmpty) return 0;
    final totalSelected = _pageHistory.fold<int>(
      0,
      (sum, page) => sum + page.length,
    );
    return totalSelected / _allItems.length;
  }

  List<T> get availableItems =>
      _isLoading
          ? []
          : _selectedIndices.map((index) => _allItems[index]).toList();
  List<T> get viewedItems =>
      _isLoading
          ? []
          : _pageHistory
              .expand((page) => page)
              .map((index) => _allItems[index])
              .toList();

  // Async loading properties
  Future<void>? get initializationFuture => _initializationFuture;
  bool get isLoading => _isLoading;
  bool get hasError => _loadingError != null;
  Object? get error => _loadingError;

  @override
  String toString() {
    if (_isLoading) return 'PaginatedList(loading...)';
    return 'PaginatedList('
        'currentPage: $currentPageNumber, '
        'totalItems: $totalItems, '
        'progress: ${(progress * 100).toStringAsFixed(1)}%'
        ')';
  }
}
