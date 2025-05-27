import 'package:flutter/material.dart';
import 'package:chatzilla/data/repositories/contact_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';

/// Demo screen to showcase optimized contact loading performance
class ContactPerformanceDemoScreen extends StatefulWidget {
  const ContactPerformanceDemoScreen({super.key});

  @override
  State<ContactPerformanceDemoScreen> createState() =>
      _ContactPerformanceDemoScreenState();
}

class _ContactPerformanceDemoScreenState
    extends State<ContactPerformanceDemoScreen> {
  final ContactRepository _contactRepository = getIt<ContactRepository>();

  String _status = 'Ready to test';
  int _loadTime = 0;
  List<Map<String, dynamic>> _contacts = [];
  Map<String, dynamic> _cacheStats = {};

  @override
  void initState() {
    super.initState();
    _updateCacheStats();
  }

  void _updateCacheStats() {
    setState(() {
      _cacheStats = _contactRepository.getCacheStats();
    });
  }

  Future<void> _testRegularLoad() async {
    setState(() {
      _status = 'Loading contacts (regular method)...';
      _loadTime = 0;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final contacts = await _contactRepository.getRegisteredContacts();
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _status = 'Loaded ${contacts.length} contacts successfully!';
          _loadTime = stopwatch.elapsedMilliseconds;
          _contacts = contacts;
        });
        _updateCacheStats();
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
          _loadTime = stopwatch.elapsedMilliseconds;
        });
      }
    }
  }

  Future<void> _testStreamLoad() async {
    setState(() {
      _status = 'Loading contacts (stream method)...';
      _loadTime = 0;
      _contacts = [];
    });

    final stopwatch = Stopwatch()..start();
    try {
      await for (final contacts
          in _contactRepository.getRegisteredContactsStream()) {
        if (mounted) {
          setState(() {
            _contacts = contacts;
            _status = 'Streaming... ${contacts.length} contacts loaded';
          });
        }
        // Break after first complete result for demo
        if (contacts.isNotEmpty) {
          stopwatch.stop();
          if (mounted) {
            setState(() {
              _status = 'Stream completed! ${contacts.length} contacts loaded';
              _loadTime = stopwatch.elapsedMilliseconds;
            });
            _updateCacheStats();
          }
          break;
        }
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _status = 'Stream error: $e';
          _loadTime = stopwatch.elapsedMilliseconds;
        });
      }
    }
  }

  void _clearCache() {
    _contactRepository.clearCache();
    setState(() {
      _status = 'Cache cleared';
      _contacts = [];
    });
    _updateCacheStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Performance Demo'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and timing
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Load Time: ${_loadTime}ms'),
                    Text('Contacts Found: ${_contacts.length}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Cache statistics
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cache Statistics:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contacts Cached: ${_cacheStats['hasContactsCache'] ?? false}',
                    ),
                    Text(
                      'Cache Size: ${_cacheStats['contactsCacheSize'] ?? 0}',
                    ),
                    Text(
                      'Cache Age: ${_cacheStats['contactsCacheAge'] ?? 'N/A'} seconds',
                    ),
                    Text(
                      'Users Cached: ${_cacheStats['hasUsersCache'] ?? false}',
                    ),
                    Text(
                      'Users Cache Size: ${_cacheStats['usersCacheSize'] ?? 0}',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testRegularLoad,
                    child: const Text('Test Regular Load'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testStreamLoad,
                    child: const Text('Test Stream Load'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _clearCache,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Clear Cache',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Contacts list
            const Text(
              'Loaded Contacts:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            Expanded(
              child:
                  _contacts.isEmpty
                      ? const Center(child: Text('No contacts loaded'))
                      : ListView.builder(
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final contact = _contacts[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(contact['name'][0].toUpperCase()),
                            ),
                            title: Text(contact['name']),
                            subtitle: Text(contact['phoneNumber']),
                            trailing: Text(
                              contact['id'].substring(0, 8) + '...',
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
