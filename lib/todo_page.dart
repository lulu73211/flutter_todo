import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/auth.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final TextEditingController _controller = TextEditingController();
  String _selectedPriority = 'medium';

  Future<void> _addTodo() async {
    if (_controller.text.isEmpty) return;

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      await FirebaseFirestore.instance.collection('todos').add({
        'text': _controller.text.trim(),
        'done': false,
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'dueDate': Timestamp.fromDate(selectedDate),
        'priority': _selectedPriority,
      });
      _controller.clear();
    }
  }

  Future<void> _toggleDone(String id, bool current) async {
    await FirebaseFirestore.instance
        .collection('todos')
        .doc(id)
        .update({'done': !current});
  }

  Future<void> _delete(String id) async {
    await FirebaseFirestore.instance.collection('todos').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Auth();
    final userId = auth.currentUser!.uid;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Todos'),
        actions: [
          IconButton(
            onPressed: () async => await auth.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('todos')
            .where('userId', isEqualTo: userId)
            .orderBy('dueDate', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur de chargement : ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          final int totalTasks = docs.length;
          final int doneTasks = docs
              .where((d) => (d.data() as Map<String, dynamic>)['done'] == true)
              .length;
          final int inProgressTasks = totalTasks - doneTasks;

          return Column(
            children: [
              //Résumé en haut
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatItem(
                          label: 'Total',
                          value: totalTasks,
                          color: cs.primary,
                        ),
                        _StatItem(
                          label: 'En cours',
                          value: inProgressTasks,
                          color: Colors.orange.shade400,
                        ),
                        _StatItem(
                          label: 'Faites',
                          value: doneTasks,
                          color: Colors.green.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              //Bloc d’ajout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              labelText: 'Nouvelle tâche',
                              hintText: 'Ex : Acheter du pain',
                            ),
                            onSubmitted: (_) => _addTodo(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedPriority,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                              value: 'low',
                              child: Text('Basse'),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('Moyenne'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('Haute'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedPriority = value);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addTodo,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              //Liste des tâches
              Expanded(
                child: docs.isEmpty
                    ? const Center(
                        child: Text('Aucune tâche pour l’instant'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          final bool done = data['done'] ?? false;
                          final Timestamp? dueTimestamp = data['dueDate'];
                          final DateTime? dueDate = dueTimestamp?.toDate();

                          final String priorityRaw =
                              (data['priority'] ?? 'medium') as String;

                          String priorityLabel;
                          Color priorityColor;
                          switch (priorityRaw) {
                            case 'low':
                              priorityLabel = 'Basse';
                              priorityColor = Colors.green.shade400;
                              break;
                            case 'high':
                              priorityLabel = 'Haute';
                              priorityColor = cs.error;
                              break;
                            case 'medium':
                            default:
                              priorityLabel = 'Moyenne';
                              priorityColor = Colors.orange.shade400;
                              break;
                          }

                          final bool isOverdue = dueDate != null &&
                              dueDate.isBefore(DateTime.now()) &&
                              !done;

                          return Card(
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: done,
                                    onChanged: (_) => _toggleDone(doc.id, done),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                data['text'] ?? '',
                                                style: tt.titleMedium?.copyWith(
                                                  color: isOverdue
                                                      ? cs.error
                                                      : cs.onSurface,
                                                  decoration: done
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (isOverdue)
                                              Icon(
                                                Icons.warning_amber_rounded,
                                                size: 18,
                                                color: cs.error,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            if (dueDate != null)
                                              Chip(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                backgroundColor: isOverdue
                                                    ? cs.errorContainer
                                                    : cs.surfaceVariant,
                                                label: Text(
                                                  'Échéance : ${dueDate.day}/${dueDate.month}/${dueDate.year}',
                                                ),
                                                labelStyle:
                                                    tt.bodySmall?.copyWith(
                                                  color: isOverdue
                                                      ? cs.onErrorContainer
                                                      : cs.onSurfaceVariant,
                                                ),
                                              ),
                                            Chip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              backgroundColor: priorityColor
                                                  .withOpacity(0.15),
                                              label: Text(
                                                  'Priorité : $priorityLabel'),
                                              labelStyle:
                                                  tt.bodySmall?.copyWith(
                                                color: priorityColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: cs.error,
                                    onPressed: () => _delete(doc.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Compteur de tasks
class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tt.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
