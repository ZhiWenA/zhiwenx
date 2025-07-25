import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Contact> _contacts = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 检查并请求联系人权限
      final PermissionStatus permission = await Permission.contacts.status;
      if (permission != PermissionStatus.granted) {
        final PermissionStatus requestedPermission = await Permission.contacts.request();
        if (requestedPermission != PermissionStatus.granted) {
          setState(() {
            _errorMessage = '需要联系人权限才能访问联系人信息';
            _isLoading = false;
          });
          return;
        }
      }

      // 获取联系人列表
      final List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false,
      );
      
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '获取联系人失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('联系人信息'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContacts,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载联系人...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadContacts,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_contacts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contacts_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '没有找到联系人',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 联系人数量统计
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.indigo.shade50,
          child: Text(
            '共找到 ${_contacts.length} 个联系人',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade700,
            ),
          ),
        ),
        
        // 联系人列表
        Expanded(
          child: ListView.builder(
            itemCount: _contacts.length,
            itemBuilder: (context, index) {
              final contact = _contacts[index];
              return _buildContactItem(contact);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactItem(Contact contact) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade100,
          child: Text(
            _getInitials(contact.displayName),
            style: TextStyle(
              color: Colors.indigo.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          contact.displayName.isNotEmpty ? contact.displayName : '未知联系人',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contact.phones.isNotEmpty)
              Text(
                '📞 ${contact.phones.first.number}',
                style: const TextStyle(fontSize: 12),
              ),
            if (contact.emails.isNotEmpty)
              Text(
                '📧 ${contact.emails.first.address}',
                style: const TextStyle(fontSize: 12),
              ),
            if (contact.organizations.isNotEmpty)
              Text(
                '🏢 ${contact.organizations.first.company}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        onTap: () {
          _showContactDetails(contact);
        },
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.split(' ');
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    }
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  void _showContactDetails(Contact contact) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(contact.displayName.isNotEmpty ? contact.displayName : '联系人详情'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (contact.name.first.isNotEmpty)
                  _buildDetailItem('名字', contact.name.first),
                if (contact.name.last.isNotEmpty)
                  _buildDetailItem('姓氏', contact.name.last),
                if (contact.name.middle.isNotEmpty)
                  _buildDetailItem('中间名', contact.name.middle),
                if (contact.name.prefix.isNotEmpty)
                  _buildDetailItem('前缀', contact.name.prefix),
                if (contact.name.suffix.isNotEmpty)
                  _buildDetailItem('后缀', contact.name.suffix),
                if (contact.organizations.isNotEmpty) ...[
                  _buildDetailItem('公司', contact.organizations.first.company),
                  if (contact.organizations.first.title.isNotEmpty)
                    _buildDetailItem('职位', contact.organizations.first.title),
                ],
                
                // 电话号码
                if (contact.phones.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '电话号码:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...contact.phones.map((phone) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('${_getPhoneLabel(phone.label)}: ${phone.number}'),
                  )),
                ],
                
                // 邮箱地址
                if (contact.emails.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '邮箱地址:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...contact.emails.map((email) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('${_getEmailLabel(email.label)}: ${email.address}'),
                  )),
                ],
                
                // 地址
                if (contact.addresses.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '地址:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...contact.addresses.map((address) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('${_getAddressLabel(address.label)}: ${_formatAddress(address)}'),
                  )),
                ],
                
                // 网站
                if (contact.websites.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '网站:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...contact.websites.map((website) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('${_getWebsiteLabel(website.label)}: ${website.url}'),
                  )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getPhoneLabel(PhoneLabel label) {
    switch (label) {
      case PhoneLabel.home:
        return '家庭';
      case PhoneLabel.work:
        return '工作';
      case PhoneLabel.mobile:
        return '手机';
      case PhoneLabel.main:
        return '主要';
      case PhoneLabel.faxWork:
        return '工作传真';
      case PhoneLabel.faxHome:
        return '家庭传真';
      case PhoneLabel.pager:
        return '寻呼机';
      case PhoneLabel.other:
        return '其他';
      default:
        return '未知';
    }
  }

  String _getEmailLabel(EmailLabel label) {
    switch (label) {
      case EmailLabel.home:
        return '家庭';
      case EmailLabel.work:
        return '工作';
      case EmailLabel.other:
        return '其他';
      default:
        return '未知';
    }
  }

  String _getAddressLabel(AddressLabel label) {
    switch (label) {
      case AddressLabel.home:
        return '家庭';
      case AddressLabel.work:
        return '工作';
      case AddressLabel.other:
        return '其他';
      default:
        return '未知';
    }
  }

  String _getWebsiteLabel(WebsiteLabel label) {
    switch (label) {
      case WebsiteLabel.homepage:
        return '主页';
      case WebsiteLabel.blog:
        return '博客';
      case WebsiteLabel.profile:
        return '个人资料';
      case WebsiteLabel.home:
        return '家庭';
      case WebsiteLabel.work:
        return '工作';
      case WebsiteLabel.other:
        return '其他';
      default:
        return '未知';
    }
  }

  String _formatAddress(Address address) {
    final parts = <String>[];
    if (address.street.isNotEmpty) parts.add(address.street);
    if (address.city.isNotEmpty) parts.add(address.city);
    if (address.state.isNotEmpty) parts.add(address.state);
    if (address.postalCode.isNotEmpty) parts.add(address.postalCode);
    if (address.country.isNotEmpty) parts.add(address.country);
    return parts.join(', ');
  }
}
