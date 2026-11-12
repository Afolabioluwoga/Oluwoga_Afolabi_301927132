// ============================================================================
//  seed_posts.js — generates ~42,000 documents across the four collections.
//  Run AFTER schema_validation.js. Idempotent (drops all four collections first).
//
//  Volume target (>= 40k total documents):
//    social_posts  : ~3,000 posts (1,000 per platform)
//    daily_metrics : ~30,000 daily snapshots (10 days × 3,000 posts)
//    comments      : ~6,000 comments (2 per post on average)
//    conversions   : ~3,000 conversions
//    TOTAL         : ~42,000 documents
// ============================================================================

db = db.getSiblingDB('afordchess');

// Drop & recreate (idempotent) ------------------------------------------------
db.social_posts .drop();
db.daily_metrics.drop();
db.comments     .drop();
db.conversions  .drop();

// Re-create the collections WITH their validators (schema_validation.js
// creates them; do not createCollection twice or MongoDB refuses) -------------
load(__dirname + '/schema_validation.js');

// ----- Helpers --------------------------------------------------------------
const platforms = ['instagram', 'tiktok', 'youtube'];

const instagramCaptions = [
  'Reel: 5-move mate puzzle 🧩', 'Carousel: top 5 opening tips', 'Story: today\'s tournament recap',
  'Reel: knight fork trick', 'Carousel: endgame basics', 'Story: meet the coaches',
  'Reel: blitz game of the week', 'Carousel: how to castle safely', 'Story: new course drop'
];
const tiktokCaptions = [
  '60-second tactic #chess', 'Duet this opening line!', 'Stitch your best move 🤔',
  'Sound on — mating attack 🎵', 'Duet: solve with me', 'Stitch: blunder challenge',
  'TikTok: fastest checkmate', 'Sound on — endgame magic', 'Duet: guess the move'
];
const youtubeCaptions = [
  'Full lesson: Sicilian Najdorf', 'Opening breakdown: Queen\'s Gambit', 'Game review: GM level',
  'Endgame lesson: Lucena position', 'Tournament recap: round 5', 'Chapter-by-chapter: King\'s Indian',
  'Full course: positional chess', 'Lesson: rook endgame patterns', 'Watch: 10-minute tactics drill'
];
const instagramFilters = ['Clarendon', 'Juno', 'Lark', 'Gingham', 'Moon'];
const tiktokSounds = [
  { id: 'snd_001', title: 'Chess Vibes - Original' },
  { id: 'snd_002', title: 'Tactical Beat' },
  { id: 'snd_003', title: 'Lo-fi Opening' },
  { id: 'snd_004', title: 'Checkmate Drop' }
];
const youtubeChapters = [
  [{ title: 'Intro', start_seconds: 0 }, { title: 'Main line', start_seconds: 45 }, { title: 'Conclusion', start_seconds: 360 }],
  [{ title: 'Opening', start_seconds: 0 }, { title: 'Middlegame', start_seconds: 120 }, { title: 'Endgame', start_seconds: 420 }],
  [{ title: 'Setup', start_seconds: 0 }, { title: 'Tactics', start_seconds: 90 }, { title: 'Recap', start_seconds: 240 }]
];
const tags = ['chess', 'chesslife', 'chesstactics', 'chesspuzzle', 'chessclub', 'beginnerchess', 'blitz', 'endgame'];

const authors = ['chessfan_01','tacticalmind','endgame_eddie','queensgambit_fan','kasparov_jr',
                 'carlsen_wannabe','fischer_lover','pawnstar','knight_rider','rook_master',
                 'bobby_f','magnus_c','judit_p','hikaru_n','fabiano_c'];

// ----- 1) social_posts (~3,000 posts: 1,000 per platform) -------------------
const POSTS_PER_PLATFORM = 1000;
const postIds = { instagram: [], tiktok: [], youtube: [] };

for (const platform of platforms) {
  const bulk = db.social_posts.initializeUnorderedBulkOp();
  for (let i = 1; i <= POSTS_PER_PLATFORM; i++) {
    const postedAt = new Date(Date.now() - Math.floor(Math.random() * 365 * 24 * 3600 * 1000));
    const course_id = 1 + (i % 10);
    let doc = {
      platform,
      external_id: platform + '-' + i,
      posted_at: postedAt,
      caption: (platform === 'instagram' ? instagramCaptions
                : platform === 'tiktok' ? tiktokCaptions : youtubeCaptions)[i % 9],
      external_url: 'https://' + platform + '.example/afordchess/' + i,
      course_id,
      tags: tags.sort(() => Math.random() - 0.5).slice(0, 3)
    };

    if (platform === 'instagram') {
      const pt = ['reel', 'carousel', 'story'][i % 3];
      doc.instagram = {
        post_type: pt,
        duration_seconds: pt === 'reel' ? 15 + (i % 60) : null,
        slides_count: pt === 'carousel' ? 3 + (i % 8) : null,
        filter_used: instagramFilters[i % instagramFilters.length]
      };
    } else if (platform === 'tiktok') {
      const pt = ['video', 'duet', 'stitch'][i % 3];
      const snd = tiktokSounds[i % tiktokSounds.length];
      doc.tiktok = {
        post_type: pt,
        sound_id: snd.id,
        sound_title: snd.title,
        duet_with: pt === 'duet' ? 'duet_user_' + (i % 50) : null,
        stitch_with: pt === 'stitch' ? 'stitch_user_' + (i % 50) : null,
        duration_seconds: 15 + (i % 180)
      };
    } else { // youtube
      doc.youtube = {
        video_id: 'yt_' + i,
        duration_seconds: 300 + (i % 1800),
        chapters: youtubeChapters[i % youtubeChapters.length],
        watch_time_seconds_avg: 60 + (i % 600)
      };
    }
    bulk.insert(doc);
  }
  bulk.execute();
  // Cache the inserted _ids for the metrics loop below
  db.social_posts.find({ platform: platform }, { _id: 1 }).forEach(d => postIds[platform].push(d._id));
}

const totalPosts = postIds.instagram.length + postIds.tiktok.length + postIds.youtube.length;
print('Inserted ' + totalPosts + ' social_posts');

// ----- 2) daily_metrics (10 days × every post = ~30,000 docs) --------------
const DAYS = 10;
let metricsCount = 0;
for (const platform of platforms) {
  let bulk = db.daily_metrics.initializeUnorderedBulkOp();
  for (let d = 0; d < DAYS; d++) {
    const day = new Date(Date.now() - d * 24 * 3600 * 1000);
    for (const postId of postIds[platform]) {
      const views = 100 + Math.floor(Math.random() * 10000);
      const likes = Math.floor(views * (0.05 + Math.random() * 0.15));
      const comments = Math.floor(views * (0.005 + Math.random() * 0.02));
      const shares = Math.floor(views * (0.01 + Math.random() * 0.05));
      const saves = Math.floor(views * (0.005 + Math.random() * 0.03));
      let doc = {
        post_id: postId, platform, date: day,
        views, likes, comments, shares, saves
      };
      if (platform === 'instagram') {
        doc.instagram = {
          reach: Math.floor(views * (0.7 + Math.random() * 0.3)),
          impressions: Math.floor(views * (1.0 + Math.random() * 0.5)),
          profile_visits: Math.floor(views * (0.01 + Math.random() * 0.05))
        };
      } else if (platform === 'tiktok') {
        doc.tiktok = {
          for_you_impressions: Math.floor(views * (0.6 + Math.random() * 0.4)),
          duets_created: Math.floor(views * (0.001 + Math.random() * 0.01)),
          stitches_created: Math.floor(views * (0.001 + Math.random() * 0.005))
        };
      } else {
        doc.youtube = {
          watch_time_minutes: Math.floor(views * (3 + Math.random() * 7)),
          avg_view_duration_seconds: 60 + Math.floor(Math.random() * 600),
          ctr: 0.02 + Math.random() * 0.08
        };
      }
      bulk.insert(doc);
      metricsCount++;
      if (metricsCount % 5000 === 0) {
        bulk.execute();
        bulk = db.daily_metrics.initializeUnorderedBulkOp();   // a bulk op cannot be reused after execute()
      }
    }
  }
  if (bulk.batches && bulk.batches.length) { bulk.execute(); } else { try { bulk.execute(); } catch (e) { /* nothing left */ } }
}
print('Inserted ' + metricsCount + ' daily_metrics');

// ----- 3) comments (2 per post on average = ~6,000 docs) -------------------
let commentsCount = 0;
for (const platform of platforms) {
  for (const postId of postIds[platform].slice(0, 1000)) {  // 2,000 posts get comments
    const bulk = db.comments.initializeUnorderedBulkOp();
    const n = 1 + Math.floor(Math.random() * 4);
    for (let c = 0; c < n; c++) {
      bulk.insert({
        post_id: postId, platform,
        external_id: platform + '-c-' + postId.toString().slice(-6) + '-' + c,
        author: authors[Math.floor(Math.random() * authors.length)],
        text: ['Great move!', 'How did you find this?', 'Mind blown 🤯',
               'Teach me please', ' subscribed!', 'What opening is this?'][c % 6],
        posted_at: new Date(Date.now() - Math.floor(Math.random() * 30 * 24 * 3600 * 1000)),
        sentiment: ['positive', 'neutral', 'negative'][Math.floor(Math.random() * 3)]
      });
      commentsCount++;
    }
    bulk.execute();
    if (commentsCount % 2000 === 0) print('  ...comments so far: ' + commentsCount);
  }
}
print('Inserted ' + commentsCount + ' comments');

// ----- 4) conversions (~3,000 docs) ----------------------------------------
const convBulk = db.conversions.initializeUnorderedBulkOp();
for (let i = 0; i < 3000; i++) {
  const platform = platforms[i % 3];
  const postId = postIds[platform][i % postIds[platform].length];
  convBulk.insert({
    post_id: postId, platform,
    converted_student_id: 13 + (i % 1500),     // ref to a PG student_id
    converted_at: new Date(Date.now() - Math.floor(Math.random() * 365 * 24 * 3600 * 1000)),
    revenue_usd_equiv: 45 + Math.random() * 200
  });
}
convBulk.execute();
print('Inserted 3000 conversions');

print('=== Final counts ===');
print('social_posts : ' + db.social_posts.countDocuments());
print('daily_metrics: ' + db.daily_metrics.countDocuments());
print('comments     : ' + db.comments.countDocuments());
print('conversions  : ' + db.conversions.countDocuments());
print('TOTAL        : ' + (
  db.social_posts.countDocuments() + db.daily_metrics.countDocuments() +
  db.comments.countDocuments() + db.conversions.countDocuments()
));
