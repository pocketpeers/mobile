import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/api_error_message.dart';
import '../../core/formatters.dart';
import '../../core/skeleton.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Lista de declaraciones juradas firmadas.
///
/// Sin [groupId], las del usuario de la sesion ("Mis declaraciones"). Con
/// [groupId], las de ese grupo, que el backend solo entrega a su administrador.
class SignedDeclarationsScreen extends ConsumerStatefulWidget {
  const SignedDeclarationsScreen({this.groupId, super.key});

  final int? groupId;

  @override
  ConsumerState<SignedDeclarationsScreen> createState() =>
      _SignedDeclarationsScreenState();
}

class _SignedDeclarationsScreenState
    extends ConsumerState<SignedDeclarationsScreen> {
  late Future<List<SignedDeclaration>> _declarations = _load();

  bool get _isGroupView => widget.groupId != null;

  Future<List<SignedDeclaration>> _load() {
    final api = ref.read(apiProvider);
    final groupId = widget.groupId;
    return groupId == null
        ? api.getMyDeclarations()
        : api.getGroupDeclarations(groupId);
  }

  Future<void> _reload() async {
    setState(() => _declarations = _load());
    await _declarations;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isGroupView ? 'Declaraciones firmadas' : 'Mis declaraciones'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<SignedDeclaration>>(
          future: _declarations,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Message(
                apiErrorMessage(snapshot.error!,
                    fallback: 'No se pudieron cargar las declaraciones'),
              );
            }
            final items = snapshot.data;
            if (items == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonList(),
              );
            }
            if (items.isEmpty) {
              return _Message(_isGroupView
                  ? 'Todavia nadie firmo la declaracion jurada en este grupo.'
                  : 'Aun no has firmado ninguna declaracion jurada. Se firma al '
                      'crear un grupo o al unirte a uno.');
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _DeclarationTile(declaration: items[index], showSigner: _isGroupView),
            );
          },
        ),
      ),
    );
  }
}

class _DeclarationTile extends StatelessWidget {
  const _DeclarationTile({required this.declaration, required this.showSigner});

  final SignedDeclaration declaration;

  /// En la vista del grupo importa quien firmo; en la propia, en que grupo.
  final bool showSigner;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (showSigner) declaration.displayGroupName,
      'Firmada el ${formatDateTime(declaration.acceptedAt)}',
      if (declaration.groupWasRenamed) 'Firmada como "${declaration.groupName}"',
      if (declaration.currentGroupName == null) 'El grupo ya no existe',
    ];
    return ListTile(
      leading: const Icon(Icons.picture_as_pdf_outlined),
      title: Text(showSigner ? declaration.fullName : declaration.displayGroupName),
      subtitle: Text(details.join('\n')),
      isThreeLine: details.length > 1,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SignedDeclarationPdfScreen(declaration: declaration),
        ),
      ),
    );
  }
}

/// Muestra el PDF firmado: la declaracion con la firma dibujada al pie.
class SignedDeclarationPdfScreen extends ConsumerStatefulWidget {
  const SignedDeclarationPdfScreen({required this.declaration, super.key});

  final SignedDeclaration declaration;

  @override
  ConsumerState<SignedDeclarationPdfScreen> createState() =>
      _SignedDeclarationPdfScreenState();
}

class _SignedDeclarationPdfScreenState
    extends ConsumerState<SignedDeclarationPdfScreen> {
  late final _pdf =
      ref.read(apiProvider).getDeclarationPdf(widget.declaration.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.declaration.displayGroupName)),
      body: FutureBuilder(
        future: _pdf,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(apiErrorMessage(snapshot.error!,
                fallback: 'No se pudo abrir el documento'));
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return PdfViewer.data(
            bytes,
            sourceName: 'declaracion-${widget.declaration.id}.pdf',
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    // Dentro de un ListView para que el RefreshIndicator siga funcionando.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [Text(text, textAlign: TextAlign.center)],
    );
  }
}
