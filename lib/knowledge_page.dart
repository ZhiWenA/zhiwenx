import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/knowledge_service.dart';
import '../models/knowledge_models.dart';

class KnowledgePage extends StatefulWidget {
  const KnowledgePage({super.key});

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 上传相关
  final TextEditingController _titleController = TextEditingController();
  List<File> _selectedFiles = [];
  bool _isUploading = false;
  
  // 搜索相关
  final TextEditingController _searchController = TextEditingController();
  List<KnowledgeSearchResult> _searchResults = [];
  bool _isSearching = false;
  final TextEditingController _topNController = TextEditingController(text: '5');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _searchController.dispose();
    _topNController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('知识库管理'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.upload_file),
              text: '文件上传',
            ),
            Tab(
              icon: Icon(Icons.search),
              text: '知识搜索',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUploadTab(),
          _buildSearchTab(),
        ],
      ),
    );
  }

  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          // 文件标题输入
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '文件标题（可选）',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: '请输入文件标题',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 文件选择
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '选择文件',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.add),
                        label: const Text('选择文件'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '支持格式：txt、pdf、md、html、docx，单文件大小限制20MB',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 已选择的文件列表
                  if (_selectedFiles.isNotEmpty) ...[
                    const Text(
                      '已选择的文件：',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedFiles.length,
                      itemBuilder: (context, index) {
                        final file = _selectedFiles[index];
                        final fileName = file.path.split('/').last;
                        final fileSizeKB = (file.lengthSync() / 1024).round();
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              _getFileIcon(fileName),
                              color: Colors.deepPurple,
                            ),
                            title: Text(fileName),
                            subtitle: Text('${fileSizeKB}KB'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _selectedFiles.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 上传按钮
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedFiles.isNotEmpty && !_isUploading
                  ? _uploadFiles
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
                disabledForegroundColor: Colors.white70,
              ),
              child: _isUploading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('上传中...'),
                      ],
                    )
                  : const Text(
                      '上传到知识库',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // 搜索输入
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '搜索知识库',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: '请输入要搜索的内容...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _topNController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '返回结果数量',
                            hintText: '默认5条',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _searchController.text.isNotEmpty && !_isSearching
                            ? _searchKnowledge
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                          disabledForegroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        child: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('搜索'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 搜索结果
          if (_searchResults.isNotEmpty) ...[
            Text(
              '搜索结果 (${_searchResults.length}条)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ExpansionTile(
                    title: Text(
                      result.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          result.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.link,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                result.url,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'ID: ${result.id}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '详细内容：',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              child: Text(
                                result.content,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }


  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf', 'md', 'html', 'docx'],
        allowMultiple: true,
      );

      if (result != null) {
        final files = result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .where((file) {
              final fileSizeBytes = file.lengthSync();
              const maxSizeBytes = 20 * 1024 * 1024; // 20MB
              return fileSizeBytes <= maxSizeBytes;
            })
            .toList();

        if (files.length != result.paths.length) {
          _showMessage('部分文件超过20MB限制，已自动过滤', isError: true);
        }

        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      _showMessage('选择文件时发生错误: $e', isError: true);
    }
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty) return;

    // 检查配置
    if (!KnowledgeService.isConfigured()) {
      _showMessage('知识库配置不完整，请检查环境变量配置', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final response = await KnowledgeService.uploadFiles(
        files: _selectedFiles,
        title: _titleController.text.isNotEmpty ? _titleController.text : null,
      );

      if (response.code == 0 || response.code == 200) {
        _showMessage('文件上传成功！');
        setState(() {
          _selectedFiles.clear();
          _titleController.clear();
        });
      } else {
        _showMessage('上传失败: ${response.msg}', isError: true);
      }
    } catch (e) {
      _showMessage('上传失败: $e', isError: true);
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _searchKnowledge() async {
    if (_searchController.text.isEmpty) return;

    // 检查配置
    if (!KnowledgeService.isConfigured()) {
      _showMessage('知识库配置不完整，请检查环境变量配置', isError: true);
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    try {
      final topN = int.tryParse(_topNController.text) ?? 5;
      final response = await KnowledgeService.searchKnowledge(
        content: _searchController.text,
        topN: topN,
      );

      if (response.code == 200 && response.data != null) {
        setState(() {
          _searchResults = response.data!;
        });
        
        if (_searchResults.isEmpty) {
          _showMessage('没有找到相关内容');
        }
      } else {
        _showMessage('搜索失败: ${response.msg}', isError: true);
      }
    } catch (e) {
      _showMessage('搜索失败: $e', isError: true);
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
        return Icons.text_snippet;
      case 'md':
        return Icons.code;
      case 'html':
        return Icons.web;
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
