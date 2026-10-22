"""Bounded per-session replay watermarks, without a small cumulative RAM cliff.

Do not evict old target watermarks: a later packet must not revive an old
sequence merely because a camera track expired. SQLite's private temporary
DB is removed at close; no persistent robot database or external service exists.
"""
import sqlite3


class SequenceHistory:
    def __init__(self, maximum_entries=100000):
        self.maximum_entries = maximum_entries
        self.count = 0
        self.failed = False
        self.connection = sqlite3.connect('', isolation_level=None)
        self.connection.execute('PRAGMA page_size=4096')
        self.connection.execute('PRAGMA max_page_count=4096')
        self.connection.execute('PRAGMA cache_size=-512')
        self.connection.execute('PRAGMA temp_store=FILE')
        self.connection.execute('PRAGMA journal_mode=MEMORY')
        self.connection.execute('CREATE TABLE watermarks (origin TEXT, source TEXT, target TEXT, sequence INTEGER NOT NULL, PRIMARY KEY(origin,source,target)) WITHOUT ROWID')

    def accept(self, key, sequence):
        if self.failed or self.connection is None:
            raise ValueError('replay history unavailable; restart the scoped session')
        try:
            old = self.connection.execute('SELECT sequence FROM watermarks WHERE origin=? AND source=? AND target=?', key).fetchone()
            if old is not None and sequence <= old[0]:
                raise ValueError('replayed observation')
            if old is None and self.count >= self.maximum_entries:
                raise ValueError('sequence history capacity')
            self.connection.execute('INSERT OR REPLACE INTO watermarks VALUES (?,?,?,?)', (*key, sequence))
            if old is None:
                self.count += 1
        except sqlite3.Error as error:
            if getattr(error, 'sqlite_errorcode', None) == getattr(sqlite3, 'SQLITE_FULL', 13) or 'full' in str(error).lower():
                raise ValueError('sequence history capacity') from error
            self.failed = True
            raise ValueError('replay history unavailable') from error

    def retire(self, origin):
        if self.connection is not None:
            try:self.count -= self.connection.execute('DELETE FROM watermarks WHERE origin=?', (origin,)).rowcount
            except sqlite3.Error:self.failed = True

    def clear(self):
        if self.connection is not None:
            try:
                self.connection.execute('DELETE FROM watermarks')
                self.count = 0
            except sqlite3.Error:self.failed = True

    def details(self):
        return {'entries': self.count, 'maximum_entries': self.maximum_entries, 'maximum_pages': 4096,
                'page_bytes': 4096, 'cache_target_kib': 512, 'failed': self.failed,
                'storage': 'private process-lifetime SQLite temporary database'}

    def close(self):
        if self.connection is not None:
            self.connection.close()
            self.connection = None
