// validation_tests.js - two bad documents the validator must REJECT.
db = db.getSiblingDB('afordchess');
// Two deliberately BAD documents: the validator must REJECT both (evidence of schema validation).
function mustReject(label, coll, doc) {
  try { db.getCollection(coll).insertOne(doc); print('FAIL - ' + label + ' was accepted (should be rejected)'); db.getCollection(coll).deleteOne({ _id: doc._id }); }
  catch (e) { print('PASS - ' + label + ' rejected: ' + (e.errInfo ? 'Document failed validation' : e.message)); }
}
mustReject('post with platform "facebook"', 'social_posts', { platform: 'facebook', external_id: 'x', posted_at: new Date(), caption: 'bad' });
mustReject('post missing caption', 'social_posts', { platform: 'tiktok', external_id: 'y', posted_at: new Date() });
