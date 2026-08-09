import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/theme.dart';
import '../../server/file_server.dart';

/// Criterio de orden de la lista. El servidor devuelve los archivos por fecha
/// descendente; reordenar es cosa de quien mira, no del disco.
enum FileSort {
  recent('Recientes'),
  name('Nombre'),
  size('Tamaño');

  const FileSort(this.label);

  final String label;
}

/// Cómo se dibuja cada archivo. La lista lee mejor un nombre largo; la
/// cuadrícula lee mejor una foto.
enum FilesView { list, grid }

/// La carpeta compartida: la superficie principal de la ventana.
///
/// Es la única tarjeta que ocupa toda la altura disponible. Enviar y conectar
/// dejaron de ser paneles hermanos porque competían con la lista por el mismo
/// espacio mientras que el trabajo real de la app, ver y mover archivos, vivía
/// debajo del pliegue.
class FilesBrowser extends StatefulWidget {
  const FilesBrowser({
    super.key,
    required this.narrow,
    required this.files,
    required this.folderPath,
    required this.onSend,
    required this.onRefresh,
    required this.onOpenFolder,
    required this.onChangeFolder,
    required this.onOpenFile,
    required this.onDeleteFiles,
  });

  final bool narrow;
  final List<SharedFile> files;
  final String folderPath;
  final VoidCallback onSend;
  final VoidCallback onRefresh;
  final VoidCallback onOpenFolder;
  final VoidCallback onChangeFolder;
  final void Function(SharedFile file) onOpenFile;
  final Future<void> Function(List<SharedFile> files) onDeleteFiles;

  @override
  State<FilesBrowser> createState() => _FilesBrowserState();
}

class _FilesBrowserState extends State<FilesBrowser> {
  final _search = TextEditingController();

  FileSort _sort = FileSort.recent;
  FilesView _view = FilesView.list;
  String _query = '';

  /// Se guardan rutas y no índices: la lista se repinta sola cada vez que el
  /// celular sube o borra algo, y un índice apuntaría entonces a otro archivo.
  Set<String> _selected = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Los archivos que se ven: primero el filtro del buscador, después el orden.
  ///
  /// Buscar no toca la selección: quien elige tres archivos, escribe para
  /// encontrar el cuarto y lo marca, espera irse con cuatro.
  List<SharedFile> get _visible {
    final needle = _query.trim().toLowerCase();
    final files = [
      for (final file in widget.files)
        if (needle.isEmpty || file.name.toLowerCase().contains(needle)) file,
    ];
    switch (_sort) {
      case FileSort.recent:
        files.sort((a, b) => b.modified.compareTo(a.modified));
      case FileSort.name:
        files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case FileSort.size:
        files.sort((a, b) => b.size.compareTo(a.size));
    }
    return files;
  }

  List<SharedFile> get _selectedFiles =>
      [for (final file in widget.files) if (_selected.contains(file.path)) file];

  @override
  void didUpdateWidget(FilesBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Un archivo que ya no está no puede seguir seleccionado: la barra de abajo
    // contaría acciones sobre algo que se borró desde el celular.
    final alive = {for (final file in widget.files) file.path};
    if (_selected.any((path) => !alive.contains(path))) {
      setState(() => _selected = _selected.intersection(alive));
    }
  }

  void _toggle(SharedFile file) {
    setState(() {
      _selected = {..._selected};
      if (!_selected.remove(file.path)) _selected.add(file.path);
    });
  }

  /// Marca o desmarca lo que se está viendo, no la carpeta entera: con un
  /// filtro puesto, "seleccionar todo" que arrastrara archivos ocultos sería
  /// una trampa, y el botón de eliminar está justo debajo.
  void _toggleAll() {
    final shown = {for (final file in _visible) file.path};
    setState(() => _selected =
        shown.every(_selected.contains) ? _selected.difference(shown) : {..._selected, ...shown});
  }

  Future<void> _deleteSelected() async {
    final files = _selectedFiles;
    if (files.isEmpty) return;

    await widget.onDeleteFiles(files);
    if (mounted) setState(() => _selected = {});
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final files = _visible;
    final filtering = _query.trim().isNotEmpty;

    return AppCard(
      // Los filetes que separan la barra de herramientas y la barra de estado
      // llegan hasta el canto de la tarjeta, así que el relleno lo pone cada
      // franja por su cuenta.
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Toolbar(
            narrow: widget.narrow,
            sort: _sort,
            view: _view,
            search: _search,
            searching: filtering,
            onSend: widget.onSend,
            onChangeFolder: widget.onChangeFolder,
            onRefresh: widget.onRefresh,
            onSearch: (value) => setState(() => _query = value),
            onClearSearch: _clearSearch,
            onSort: (value) => setState(() => _sort = value),
            onView: (value) => setState(() => _view = value),
          ),
          const _Rule(),
          Expanded(
            child: files.isEmpty
                ? (filtering
                    ? _NoMatch(query: _query.trim(), onClear: _clearSearch)
                    : _Empty(onSend: widget.onSend))
                : _FilesArea(
                    view: _view,
                    narrow: widget.narrow,
                    files: files,
                    selected: _selected,
                    allSelected: _selected.length == files.length,
                    onToggle: _toggle,
                    onToggleAll: _toggleAll,
                    onOpen: widget.onOpenFile,
                  ),
          ),
          const _Rule(),
          if (_selected.isEmpty)
            _StatusBar(
              files: files,
              total: widget.files.length,
              folderPath: widget.folderPath,
              onOpenFolder: widget.onOpenFolder,
            )
          else
            _SelectionBar(
              count: _selected.length,
              onClear: () => setState(() => _selected = {}),
              onDelete: _deleteSelected,
            ),
        ],
      ),
    );
  }
}

/// Enviar, carpeta y las dos preferencias de vista. Es la fila que MEGA pone
/// encima de los archivos, con lo que esta app puede sostener de verdad: aquí
/// no hay carpetas que crear ni papelera a la que ir.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.narrow,
    required this.sort,
    required this.view,
    required this.search,
    required this.searching,
    required this.onSend,
    required this.onChangeFolder,
    required this.onRefresh,
    required this.onSearch,
    required this.onClearSearch,
    required this.onSort,
    required this.onView,
  });

  final bool narrow;
  final FileSort sort;
  final FilesView view;
  final TextEditingController search;
  final bool searching;
  final VoidCallback onSend;
  final VoidCallback onChangeFolder;
  final VoidCallback onRefresh;
  final void Function(String value) onSearch;
  final VoidCallback onClearSearch;
  final void Function(FileSort value) onSort;
  final void Function(FilesView value) onView;

  @override
  Widget build(BuildContext context) {
    final actions = [
      FilledButton.icon(
        onPressed: onSend,
        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
        label: const Text('Subir'),
      ),
      OutlinedButton.icon(
        onPressed: onChangeFolder,
        icon: const Icon(Icons.folder_open_rounded, size: 18),
        label: const Text('Cambiar carpeta'),
      ),
    ];

    final field = _SearchField(
      controller: search,
      searching: searching,
      onChanged: onSearch,
      onClear: onClearSearch,
    );

    final tools = [
      _SortMenu(sort: sort, onSort: onSort),
      const SizedBox(width: Space.sm),
      _ViewToggle(view: view, onView: onView),
      const SizedBox(width: Space.sm),
      IconButton(
        onPressed: onRefresh,
        tooltip: 'Actualizar',
        icon: const Icon(Icons.refresh_rounded, size: 18),
        color: AppColors.textMuted,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: narrow
          // El buscador se lleva su propia línea: comprimido entre dos botones
          // no le queda ancho para mostrar lo que se escribió.
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: Space.sm, runSpacing: Space.sm, children: actions),
                const SizedBox(height: Space.md),
                field,
                const SizedBox(height: Space.md),
                Row(children: tools),
              ],
            )
          : Row(
              children: [
                actions[0],
                const SizedBox(width: Space.sm),
                actions[1],
                const SizedBox(width: Space.lg),
                // El buscador ocupa el hueco que antes era aire: es el control
                // que más se agradece que sea ancho.
                Expanded(child: field),
                const SizedBox(width: Space.lg),
                ...tools,
              ],
            ),
    );
  }
}

/// Filtra por nombre mientras se escribe. No pregunta al servidor: la carpeta
/// entera ya está en memoria, y una petición por tecla sería trabajo de red
/// para un `contains`.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.searching,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool searching;
  final void Function(String value) onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Buscar por nombre',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          filled: true,
          fillColor: AppColors.surfaceMuted,
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
          prefixIconConstraints: const BoxConstraints.tightFor(width: 38, height: 38),
          suffixIcon: searching
              ? IconButton(
                  onPressed: onClear,
                  tooltip: 'Limpiar',
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: AppColors.textMuted,
                  constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                  padding: EdgeInsets.zero,
                )
              : null,
          suffixIconConstraints: const BoxConstraints.tightFor(width: 38, height: 38),
          contentPadding: const EdgeInsets.symmetric(vertical: Space.sm),
          // Relleno sin canto en reposo: es un campo dentro de una tarjeta, no
          // otro rectángulo con borde. El foco sí se dibuja, que es cuando hace
          // falta saber dónde está el cursor.
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.control),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.control),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.control),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.onSort});

  final FileSort sort;
  final void Function(FileSort value) onSort;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<FileSort>(
      initialValue: sort,
      onSelected: onSort,
      tooltip: 'Ordenar',
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.inset),
        side: const BorderSide(color: AppColors.border),
      ),
      itemBuilder: (context) => [
        for (final value in FileSort.values)
          PopupMenuItem(value: value, child: Text(value.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderStrong),
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sort.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: Space.xs),
            const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Lista o cuadrícula. Un par de botones pegados, no dos controles sueltos: son
/// dos estados de la misma preferencia.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onView});

  final FilesView view;
  final void Function(FilesView value) onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewButton(
            icon: Icons.view_list_rounded,
            tooltip: 'Ver como lista',
            active: view == FilesView.list,
            onPressed: () => onView(FilesView.list),
          ),
          _ViewButton(
            icon: Icons.grid_view_rounded,
            tooltip: 'Ver como cuadrícula',
            active: view == FilesView.grid,
            onPressed: () => onView(FilesView.grid),
          ),
        ],
      ),
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // El estado activo se dice con relleno y color, no con un borde extra: el
    // par ya vive dentro de un borde y un segundo canto los partiría en dos
    // controles distintos.
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(Radii.control - 2),
        child: AnimatedContainer(
          duration: kMotion,
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
          decoration: BoxDecoration(
            color: active ? AppColors.accentDeep : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.control - 2),
          ),
          child: Icon(icon, size: 18, color: active ? AppColors.accent : AppColors.textMuted),
        ),
      ),
    );
  }
}

class _FilesArea extends StatelessWidget {
  const _FilesArea({
    required this.view,
    required this.narrow,
    required this.files,
    required this.selected,
    required this.allSelected,
    required this.onToggle,
    required this.onToggleAll,
    required this.onOpen,
  });

  final FilesView view;
  final bool narrow;
  final List<SharedFile> files;
  final Set<String> selected;
  final bool allSelected;
  final void Function(SharedFile file) onToggle;
  final VoidCallback onToggleAll;
  final void Function(SharedFile file) onOpen;

  @override
  Widget build(BuildContext context) {
    if (view == FilesView.grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(Space.lg),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: Space.md,
          crossAxisSpacing: Space.md,
          childAspectRatio: 0.82,
        ),
        itemCount: files.length,
        itemBuilder: (context, index) => _FileTile(
          file: files[index],
          checked: selected.contains(files[index].path),
          onToggle: () => onToggle(files[index]),
          onOpen: () => onOpen(files[index]),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ListHeader(narrow: narrow, allSelected: allSelected, onToggleAll: onToggleAll),
        const _Rule(),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: files.length,
            itemBuilder: (context, index) => _FileRow(
              file: files[index],
              narrow: narrow,
              checked: selected.contains(files[index].path),
              divided: index > 0,
              onToggle: () => onToggle(files[index]),
              onOpen: () => onOpen(files[index]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Los nombres de las columnas de la vista de lista, y la casilla que
/// selecciona todo.
class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.narrow, required this.allSelected, required this.onToggleAll});

  final bool narrow;
  final bool allSelected;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.lg, Space.sm),
      child: Row(
        children: [
          _Check(value: allSelected, onChanged: onToggleAll, tooltip: 'Seleccionar todo'),
          const SizedBox(width: Space.md),
          const Expanded(child: Text('Nombre', style: style)),
          const SizedBox(width: 92, child: Text('Tamaño', style: style)),
          if (!narrow) const SizedBox(width: 110, child: Text('Fecha', style: style)),
          // Deja hueco al control de fila, para que las cabeceras no queden
          // desalineadas con las columnas que nombran.
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

/// Un archivo en la vista de lista.
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.narrow,
    required this.checked,
    required this.divided,
    required this.onToggle,
    required this.onOpen,
  });

  final SharedFile file;
  final bool narrow;
  final bool checked;

  /// Todas las filas menos la primera dibujan la línea por encima, para que la
  /// lista nunca abra ni cierre con una raya suelta.
  final bool divided;

  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: kMotion,
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.lg, Space.sm),
      decoration: BoxDecoration(
        // La selección se tiñe con el azul profundo del logo. Es el mismo color
        // que ya marca el arrastre, y no hace falta un segundo acento para
        // decir "esto está elegido".
        color: checked ? AppColors.accentDeep : null,
        border: divided
            ? const Border(top: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        children: [
          _Check(value: checked, onChanged: onToggle, tooltip: 'Seleccionar ${file.name}'),
          const SizedBox(width: Space.md),
          Icon(iconForFile(file.name), size: 20, color: AppColors.textMuted),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              file.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 92,
            child: Text(formatBytes(file.size), style: kMonoStyle.copyWith(color: AppColors.textMuted)),
          ),
          if (!narrow)
            SizedBox(
              width: 110,
              child: Text(formatWhen(file.modified),
                  style: kMonoStyle.copyWith(color: AppColors.textMuted)),
            ),
          // Solo abrir. Eliminar salió de la fila cuando la selección pasó a
          // hacerlo en lote: una papelera repetida en cada línea le daba a la
          // acción destructiva el mismo peso que al nombre del archivo, y una
          // columna entera de ellas era lo más ruidoso de la lista.
          _RowAction(icon: Icons.open_in_new_rounded, tooltip: 'Abrir', onPressed: onOpen),
        ],
      ),
    );
  }
}

/// Un archivo en la vista de cuadrícula.
///
/// Las imágenes se pintan de verdad. Esa es la razón de que exista esta vista:
/// buscar una foto por su nombre de archivo es exactamente lo que nadie sabe
/// hacer.
class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.checked,
    required this.onToggle,
    required this.onOpen,
  });

  final SharedFile file;
  final bool checked;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isImage = imageContentType(file.name) != null;

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(Radii.inset),
      child: AnimatedContainer(
        duration: kMotion,
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: checked ? AppColors.accentDeep : AppColors.surfaceMuted,
          border: Border.all(color: checked ? AppColors.accent : AppColors.border),
          borderRadius: BorderRadius.circular(Radii.inset),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.control),
                      child: isImage
                          ? Image.file(
                              File(file.path),
                              fit: BoxFit.cover,
                              // Una imagen rota no debe dejar un hueco: la
                              // carpeta la puede vaciar el celular a mitad de
                              // pintado.
                              errorBuilder: (context, error, stack) =>
                                  _TileIcon(name: file.name),
                            )
                          : _TileIcon(name: file.name),
                    ),
                  ),
                  Positioned(
                    top: Space.xs,
                    left: Space.xs,
                    // Encima de una foto, una casilla transparente con un
                    // borde fino desaparece. El fondo opaco es lo que la
                    // mantiene legible sobre cualquier imagen.
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(Radii.control),
                      ),
                      child: _Check(
                        value: checked,
                        onChanged: onToggle,
                        tooltip: 'Seleccionar ${file.name}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              formatBytes(file.size),
              style: kMonoStyle.copyWith(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Icon(iconForFile(name), size: 40, color: AppColors.textMuted),
    );
  }
}

/// La franja de abajo cuando no hay nada elegido: qué carpeta se está
/// compartiendo y cuánto pesa.
class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.files,
    required this.total,
    required this.folderPath,
    required this.onOpenFolder,
  });

  /// Lo que se está viendo, ya filtrado.
  final List<SharedFile> files;

  /// Cuántos hay en la carpeta. Con un filtro puesto, la cuenta a secas haría
  /// pensar que desaparecieron archivos.
  final int total;

  final String folderPath;
  final VoidCallback onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final bytes = files.fold<int>(0, (sum, file) => sum + file.size);
    final count = files.length == total
        ? (total == 1 ? '1 archivo' : '$total archivos')
        : '${files.length} de $total';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
      child: Row(
        children: [
          // La ruta hace de etiqueta y de control a la vez: dice qué carpeta
          // está compartida y la abre.
          Expanded(
            child: Tooltip(
              message: 'Abrir en el explorador de archivos',
              child: InkWell(
                onTap: onOpenFolder,
                borderRadius: BorderRadius.circular(Radii.control),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_outlined, size: 15, color: AppColors.textMuted),
                    const SizedBox(width: Space.sm),
                    Flexible(
                      child: Text(
                        folderPath,
                        style: kMonoStyle.copyWith(color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.lg),
          Text(
            '$count · ${formatBytes(bytes)}',
            style: kMonoStyle.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// La misma franja cuando hay archivos elegidos. Sustituye a la de estado en
/// vez de sumarse: una barra que aparece empujando el contenido hacia arriba
/// hace saltar la lista justo cuando se está apuntando a una fila.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count, required this.onClear, required this.onDelete});

  final int count;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == 1 ? '1 seleccionado' : '$count seleccionados',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('Quitar selección'),
          ),
          const SizedBox(width: Space.sm),
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Eliminar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.borderStrong),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_downward_rounded, size: 40, color: AppColors.textMuted),
          const SizedBox(height: Space.md),
          const Text(
            'Todavía no hay archivos',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: Space.xs + 2),
          const Text(
            'Suelta archivos en esta ventana, o escanea el QR desde el celular.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
          const SizedBox(height: Space.xl - 4),
          FilledButton(onPressed: onSend, child: const Text('Buscar en la PC')),
        ],
      ),
    );
  }
}

/// El filtro no encontró nada. Distinto de la carpeta vacía: aquí hay archivos,
/// solo que ninguno se llama así, y la salida es borrar lo escrito.
class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMuted),
          const SizedBox(height: Space.md),
          Text(
            'Ningún archivo se llama "$query"',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: Space.xl - 4),
          OutlinedButton(onPressed: onClear, child: const Text('Limpiar la búsqueda')),
        ],
      ),
    );
  }
}

/// Casilla de selección con el tamaño de la ventana, no el de Material.
class _Check extends StatelessWidget {
  const _Check({required this.value, required this.onChanged, required this.tooltip});

  final bool value;
  final VoidCallback onChanged;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onChanged,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: AnimatedContainer(
            duration: kMotion,
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? AppColors.accent : Colors.transparent,
              border: Border.all(color: value ? AppColors.accent : AppColors.borderStrong),
              borderRadius: BorderRadius.circular(Radii.control - 5),
            ),
            child: value
                ? const Icon(Icons.check_rounded, size: 14, color: AppColors.accentInk)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Control de fila solo con icono. Apagado en reposo, con su color al pasar por
/// encima, al recibir el foco y al pulsarlo.
class _RowAction extends StatelessWidget {
  const _RowAction({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      // Lleva el nombre accesible además de la etiqueta al pasar por encima,
      // para que quitar el texto visible no se lleve por delante el significado
      // del control.
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed)) {
            return AppColors.accent;
          }
          return AppColors.textMuted;
        }),
        // El salto de apagado a color es demasiado pequeño para ser por sí solo
        // un indicador de foco, y quien usa el teclado no tiene puntero que le
        // diga dónde está. El foco recibe el mismo peso que la pulsación.
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) {
            return AppColors.accent.withValues(alpha: 0.22);
          }
          if (states.contains(WidgetState.hovered)) {
            return AppColors.accent.withValues(alpha: 0.10);
          }
          return null;
        }),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: AppColors.border);
}

const _imageExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.avif', '.bmp', '.svg', '.heic'};
const _videoExtensions = {'.mp4', '.mkv', '.mov', '.avi', '.webm', '.m4v'};
const _audioExtensions = {'.mp3', '.wav', '.flac', '.ogg', '.m4a', '.aac'};
const _archiveExtensions = {'.zip', '.rar', '.7z', '.tar', '.gz', '.xz', '.zst'};
const _documentExtensions = {'.txt', '.md', '.doc', '.docx', '.odt', '.rtf', '.csv', '.xlsx'};

/// El icono con el que se dibuja un archivo según su extensión.
///
/// Todos salen del mismo gris apagado: el acento de esta app es uno solo y no
/// se gasta en decorar una lista.
IconData iconForFile(String name) {
  final extension = p.extension(name).toLowerCase();
  if (_imageExtensions.contains(extension)) return Icons.image_outlined;
  if (_videoExtensions.contains(extension)) return Icons.movie_outlined;
  if (_audioExtensions.contains(extension)) return Icons.audiotrack_rounded;
  if (_archiveExtensions.contains(extension)) return Icons.folder_zip_outlined;
  if (extension == '.pdf') return Icons.picture_as_pdf_outlined;
  if (_documentExtensions.contains(extension)) return Icons.description_outlined;
  return Icons.insert_drive_file_outlined;
}
