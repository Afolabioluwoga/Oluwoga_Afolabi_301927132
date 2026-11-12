// index_demo.js - COLLSCAN -> IXSCAN on daily_metrics (re-runnable, runs on a fresh database).
//  Query: daily views of ONE post over the last 90 days.
db = db.getSiblingDB('afordchess');

// start clean: drop the demo index if it exists (never fails if it does not)
try { db.daily_metrics.dropIndex('idx_post_date'); } catch (e) { print('  (no old idx_post_date to drop)'); }

const total = db.daily_metrics.countDocuments();
const sample = db.daily_metrics.findOne({}, { post_id: 1 });
if (!sample) { print('No daily_metrics documents - run seed_posts.js first.'); quit(1); }
const postId = sample.post_id;
const since = new Date(Date.now() - 90 * 24 * 3600 * 1000);
const q = { post_id: postId, date: { $gte: since } };

function stageOf(p) {            // walk down to the leaf stage name
  let n = p; while (n.inputStage) n = n.inputStage; return n.stage + (n.indexName ? ' (' + n.indexName + ')' : '');
}
function run(label) {
  const e = db.daily_metrics.find(q).explain('executionStats');
  const es = e.executionStats;
  print('\n===== ' + label + ' =====');
  print('  Stage      : ' + stageOf(e.queryPlanner.winningPlan));
  print('  Docs       : ' + es.totalDocsExamined + ' examined, ' + es.nReturned + ' returned, ' + es.totalKeysExamined + ' keys');
  print('  Time ms    : ' + es.executionTimeMillis);
}
print('daily_metrics documents: ' + total);
run('BEFORE index (expected COLLSCAN)');
db.daily_metrics.createIndex({ post_id: 1, date: 1 }, { name: 'idx_post_date' });
print('\n  Created index idx_post_date on { post_id: 1, date: 1 }');
run('AFTER index (expected IXSCAN)');
