// ============================================================================
//  aggregations.js — three pipelines answering business questions on the
//  MongoDB social / metrics collections.
// ============================================================================

db = db.getSiblingDB('afordchess');

print('\n===== AGG 1: engagement per platform (last 30 days) =====');
//  Sum views, likes, comments, shares, saves across daily_metrics per platform
//  for the last 30 days, plus an engagement_rate = (likes+comments+shares)/views.
db.daily_metrics.aggregate([
  { $match: { date: { $gte: new Date(Date.now() - 30 * 24 * 3600 * 1000) } } },
  { $group: {
      _id: '$platform',
      total_views:    { $sum: '$views' },
      total_likes:    { $sum: '$likes' },
      total_comments: { $sum: '$comments' },
      total_shares:   { $sum: '$shares' },
      total_saves:    { $sum: '$saves' },
      snapshot_count: { $sum: 1 }
  }},
  { $addFields: {
      engagement_rate: {
        $round: [
          { $multiply: [
              100,
              { $divide: [
                  { $add: ['$total_likes', '$total_comments', '$total_shares'] },
                  { $max: ['$total_views', 1] }
              ] }
          ] },
          2
        ]
      }
  }},
  { $sort: { total_views: -1 } }
]).forEach(d => printjson(d));


print('\n===== AGG 2: best-performing post TYPES per platform =====');
//  For each platform, group by platform-specific post_type and rank by
//  total views over all daily snapshots.
//  Instagram: $instagram.post_type
//  TikTok   : $tiktok.post_type
//  YouTube  : constant 'video' (only one type)
db.social_posts.aggregate([
  { $lookup: {
      from: 'daily_metrics',
      localField: '_id', foreignField: 'post_id',
      as: 'metrics'
  }},
  { $unwind: '$metrics' },
  { $addFields: {
      post_type: {
        $switch: {
          branches: [
            { case: { $eq: ['$platform', 'instagram'] }, then: '$instagram.post_type' },
            { case: { $eq: ['$platform', 'tiktok']    }, then: '$tiktok.post_type' },
            { case: { $eq: ['$platform', 'youtube']   }, then: 'video' }
          ],
          default: 'unknown'
        }
      }
  }},
  { $group: {
      _id: { platform: '$platform', post_type: '$post_type' },
      total_views:   { $sum: '$metrics.views' },
      total_likes:   { $sum: '$metrics.likes' },
      post_count:    { $sum: 1 }
  }},
  { $sort: { '_id.platform': 1, total_views: -1 } }
]).forEach(d => printjson(d));


print('\n===== AGG 3: posts linked to conversions (revenue per post) =====');
//  Join conversions → social_posts, then rank posts by total converted revenue.
db.conversions.aggregate([
  { $group: {
      _id: '$post_id',
      conversions:    { $sum: 1 },
      revenue_usd:    { $sum: '$revenue_usd_equiv' },
      platforms:      { $addToSet: '$platform' }
  }},
  { $lookup: {
      from: 'social_posts',
      localField: '_id', foreignField: '_id',
      as: 'post'
  }},
  { $unwind: '$post' },
  { $project: {
      _id: 0,
      platform: '$post.platform',
      external_id: '$post.external_id',
      caption: '$post.caption',
      conversions: 1,
      revenue_usd: { $round: ['$revenue_usd', 2] }
  }},
  { $sort: { revenue_usd: -1 } },
  { $limit: 10 }
]).forEach(d => printjson(d));


print('\n===== AGG 4 (bonus): top sound on TikTok by duets created =====');
db.daily_metrics.aggregate([
  { $match: { platform: 'tiktok' } },
  { $lookup: {
      from: 'social_posts',
      let: { pid: '$post_id' },
      pipeline: [
        { $match: { $expr: { $eq: ['$_id', '$$pid'] } } },
        { $project: { sound_title: '$tiktok.sound_title' } }
      ],
      as: 'post'
  }},
  { $unwind: '$post' },
  { $group: {
      _id: '$post.sound_title',
      total_duets:    { $sum: '$tiktok.duets_created' },
      total_views:    { $sum: '$views' }
  }},
  { $sort: { total_duets: -1 } },
  { $limit: 5 }
]).forEach(d => printjson(d));
