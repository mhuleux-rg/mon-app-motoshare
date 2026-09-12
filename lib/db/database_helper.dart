import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/checklist_item_reponse.dart';
import '../models/client.dart';
import '../models/photo_visite.dart';
import '../models/visite.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'visite_pv.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE photos ADD COLUMN type TEXT NOT NULL DEFAULT 'photo'");
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE clients (
          id TEXT PRIMARY KEY,
          nom TEXT NOT NULL,
          adresse TEXT NOT NULL,
          telephone TEXT,
          email TEXT,
          notes TEXT,
          dateCreation TEXT NOT NULL
        )
      ''');
      await db.execute('ALTER TABLE visites ADD COLUMN clientId TEXT');
      await db.execute('CREATE INDEX idx_visites_client ON visites (clientId)');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        adresse TEXT NOT NULL,
        telephone TEXT,
        email TEXT,
        notes TEXT,
        dateCreation TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE visites (
        id TEXT PRIMARY KEY,
        clientId TEXT,
        client TEXT NOT NULL,
        adresse TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        nomTechnicien TEXT,
        notesGenerales TEXT,
        cloturee INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE photos (
        id TEXT PRIMARY KEY,
        visiteId TEXT NOT NULL,
        cheminFichier TEXT NOT NULL,
        legende TEXT,
        dateAjout TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        type TEXT NOT NULL DEFAULT 'photo',
        FOREIGN KEY (visiteId) REFERENCES visites (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE checklist_reponses (
        id TEXT PRIMARY KEY,
        visiteId TEXT NOT NULL,
        sectionId TEXT NOT NULL,
        itemId TEXT NOT NULL,
        label TEXT NOT NULL,
        typeItem TEXT NOT NULL,
        valeurTexte TEXT,
        valeurNombre REAL,
        valeurCase INTEGER,
        unite TEXT,
        aVerifierSurSite INTEGER NOT NULL DEFAULT 0,
        commentaire TEXT,
        FOREIGN KEY (visiteId) REFERENCES visites (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_photos_visite ON photos (visiteId)');
    await db.execute('CREATE INDEX idx_checklist_visite ON checklist_reponses (visiteId)');
    await db.execute('CREATE INDEX idx_visites_client ON visites (clientId)');
  }

  // ---------- Clients ----------

  Future<void> insertClient(Client client) async {
    final db = await database;
    await db.insert('clients', client.toMap());
  }

  Future<void> updateClient(Client client) async {
    final db = await database;
    await db.update('clients', client.toMap(), where: 'id = ?', whereArgs: [client.id]);
  }

  Future<void> deleteClient(String id) async {
    final db = await database;
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Client>> getClients() async {
    final db = await database;
    final rows = await db.query('clients', orderBy: 'nom ASC');
    return rows.map((r) => Client.fromMap(r)).toList();
  }

  Future<Client?> getClient(String id) async {
    final db = await database;
    final rows = await db.query('clients', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Client.fromMap(rows.first);
  }

  Future<List<Visite>> getVisitesParClient(String clientId) async {
    final db = await database;
    final rows = await db.query('visites', where: 'clientId = ?', whereArgs: [clientId], orderBy: 'date DESC');
    return rows.map((r) => Visite.fromMap(r)).toList();
  }

  // ---------- Visites ----------

  Future<void> insertVisite(Visite visite) async {
    final db = await database;
    await db.insert('visites', visite.toMap());
  }

  Future<void> updateVisite(Visite visite) async {
    final db = await database;
    await db.update('visites', visite.toMap(), where: 'id = ?', whereArgs: [visite.id]);
  }

  Future<void> deleteVisite(String id) async {
    final db = await database;
    await db.delete('photos', where: 'visiteId = ?', whereArgs: [id]);
    await db.delete('checklist_reponses', where: 'visiteId = ?', whereArgs: [id]);
    await db.delete('visites', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Visite>> getVisites({String? recherche}) async {
    final db = await database;
    if (recherche != null && recherche.trim().isNotEmpty) {
      final motif = '%${recherche.trim()}%';
      final rows = await db.query(
        'visites',
        where: 'client LIKE ? OR adresse LIKE ?',
        whereArgs: [motif, motif],
        orderBy: 'date DESC',
      );
      return rows.map((r) => Visite.fromMap(r)).toList();
    }
    final rows = await db.query('visites', orderBy: 'date DESC');
    return rows.map((r) => Visite.fromMap(r)).toList();
  }

  Future<Visite?> getVisite(String id) async {
    final db = await database;
    final rows = await db.query('visites', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Visite.fromMap(rows.first);
  }

  // ---------- Photos ----------

  Future<void> insertPhoto(PhotoVisite photo) async {
    final db = await database;
    await db.insert('photos', photo.toMap());
  }

  Future<void> deletePhoto(String id) async {
    final db = await database;
    await db.delete('photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePhotoLegende(String id, String legende) async {
    final db = await database;
    await db.update('photos', {'legende': legende}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PhotoVisite>> getPhotos(String visiteId) async {
    final db = await database;
    final rows = await db.query('photos', where: 'visiteId = ?', whereArgs: [visiteId], orderBy: 'dateAjout ASC');
    return rows.map((r) => PhotoVisite.fromMap(r)).toList();
  }

  // ---------- Checklist ----------

  Future<void> upsertChecklistReponse(ChecklistItemReponse reponse) async {
    final db = await database;
    await db.insert(
      'checklist_reponses',
      reponse.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChecklistItemReponse>> getChecklistReponses(String visiteId) async {
    final db = await database;
    final rows = await db.query('checklist_reponses', where: 'visiteId = ?', whereArgs: [visiteId]);
    return rows.map((r) => ChecklistItemReponse.fromMap(r)).toList();
  }
}
