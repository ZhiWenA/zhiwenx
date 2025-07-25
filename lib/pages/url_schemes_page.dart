import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/url_schemes_service.dart';
import '../models/url_scheme_config.dart';

class UrlSchemesPage extends StatefulWidget {
  const UrlSchemesPage({super.key});

  @override
  State<UrlSchemesPage> createState() => _UrlSchemesPageState();
}

class _UrlSchemesPageState extends State<UrlSchemesPage> {
  final UrlSchemesService _urlSchemesService = UrlSchemesService();
  List<UrlSchemeItem> _schemes = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSchemes();
  }

  Future<void> _loadSchemes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _urlSchemesService.initialize();
      setState(() {
        _schemes = _urlSchemesService.getAllSchemes();
        _categories = _urlSchemesService.getCategories();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载配置失败: $e')),
        );
      }
    }
  }

  List<UrlSchemeItem> get _filteredSchemes {
    var filtered = _schemes;

    // 按类别过滤
    if (_selectedCategory != null) {
      filtered = filtered.where((scheme) => scheme.category == _selectedCategory).toList();
    }

    // 按搜索查询过滤
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((scheme) {
        return scheme.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            scheme.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            scheme.id.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  Future<void> _launchScheme(UrlSchemeItem scheme) async {
    if (scheme.parameters.isEmpty) {
      // 无参数，直接启动
      try {
        await _urlSchemesService.launchUrlScheme(scheme.id, {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已启动 ${scheme.name}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('启动失败: $e')),
          );
        }
      }
    } else {
      // 有参数，显示参数输入对话框
      _showParameterDialog(scheme);
    }
  }

  Future<void> _showParameterDialog(UrlSchemeItem scheme) async {
    final Map<String, TextEditingController> controllers = {};
    final Map<String, String> parameters = {};

    // 初始化控制器
    for (final param in scheme.parameters.entries) {
      controllers[param.key] = TextEditingController(
        text: param.value.defaultValue ?? '',
      );
      if (param.value.defaultValue != null) {
        parameters[param.key] = param.value.defaultValue!;
      }
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('启动 ${scheme.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(scheme.description),
              const SizedBox(height: 16),
              ...scheme.parameters.entries.map((entry) {
                final paramName = entry.key;
                final paramConfig = entry.value;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextFormField(
                    controller: controllers[paramName],
                    decoration: InputDecoration(
                      labelText: paramConfig.name,
                      hintText: paramConfig.description,
                      border: const OutlineInputBorder(),
                      suffixIcon: paramConfig.required
                          ? const Icon(Icons.star, color: Colors.red, size: 16)
                          : null,
                    ),
                    onChanged: (value) {
                      parameters[paramName] = value;
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              // 验证必需参数
              bool valid = true;
              for (final entry in scheme.parameters.entries) {
                final paramName = entry.key;
                final paramConfig = entry.value;
                final value = parameters[paramName] ?? '';
                
                if (paramConfig.required && value.isEmpty) {
                  valid = false;
                  break;
                }
              }
              
              if (valid) {
                Navigator.of(context).pop(parameters);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请填写所有必需参数')),
                );
              }
            },
            child: const Text('启动'),
          ),
        ],
      ),
    );

    // 清理控制器
    for (final controller in controllers.values) {
      controller.dispose();
    }

    if (result != null) {
      try {
        await _urlSchemesService.launchUrlScheme(scheme.id, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已启动 ${scheme.name}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('启动失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleScheme(UrlSchemeItem scheme) async {
    try {
      await _urlSchemesService.toggleScheme(scheme.id, !scheme.enabled);
      await _loadSchemes();
      if (mounted) {
        final status = scheme.enabled ? '禁用' : '启用';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已${status} ${scheme.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  void _showSchemeDetails(UrlSchemeItem scheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(scheme.name),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'ID', value: scheme.id),
              _DetailRow(label: '描述', value: scheme.description),
              _DetailRow(label: 'Scheme', value: scheme.scheme),
              _DetailRow(label: 'URL模板', value: scheme.urlTemplate),
              _DetailRow(label: '类别', value: scheme.category ?? '无'),
              _DetailRow(label: '状态', value: scheme.enabled ? '启用' : '禁用'),
              if (scheme.parameters.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('参数:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...scheme.parameters.entries.map((entry) {
                  final param = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ${param.name} (${param.type})'),
                        Text('  ${param.description}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        if (param.required)
                          const Text('  必需参数',
                              style: TextStyle(fontSize: 12, color: Colors.red)),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Clipboard.setData(ClipboardData(text: scheme.urlTemplate));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL模板已复制到剪贴板')),
              );
            },
            child: const Text('复制URL'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('URL Schemes 管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchemes,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 打开设置页面
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索和过滤栏
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: '搜索 URL Schemes',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('全部'),
                        selected: _selectedCategory == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = selected ? null : _selectedCategory;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ..._categories.map((category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category),
                              selected: _selectedCategory == category,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory = selected ? category : null;
                                });
                              },
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSchemes.isEmpty
                    ? const Center(child: Text('没有找到匹配的 URL Schemes'))
                    : ListView.builder(
                        itemCount: _filteredSchemes.length,
                        itemBuilder: (context, index) {
                          final scheme = _filteredSchemes[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: scheme.enabled
                                    ? Colors.green
                                    : Colors.grey,
                                child: Text(
                                  scheme.name.substring(0, 1),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(scheme.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(scheme.description),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (scheme.category != null)
                                        Chip(
                                          label: Text(scheme.category!),
                                          backgroundColor: Colors.blue.shade100,
                                          labelStyle: const TextStyle(fontSize: 12),
                                        ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${scheme.parameters.length} 个参数',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'launch':
                                      _launchScheme(scheme);
                                      break;
                                    case 'toggle':
                                      _toggleScheme(scheme);
                                      break;
                                    case 'details':
                                      _showSchemeDetails(scheme);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'launch',
                                    child: ListTile(
                                      leading: Icon(Icons.launch),
                                      title: Text('启动'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: ListTile(
                                      leading: Icon(scheme.enabled
                                          ? Icons.toggle_on
                                          : Icons.toggle_off),
                                      title: Text(scheme.enabled ? '禁用' : '启用'),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'details',
                                    child: ListTile(
                                      leading: Icon(Icons.info),
                                      title: Text('详情'),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => _launchScheme(scheme),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 添加新的 URL Scheme
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
