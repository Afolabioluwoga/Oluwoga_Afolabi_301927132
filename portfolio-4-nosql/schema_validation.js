// ============================================================================
//  schema_validation.js — create the four MongoDB collections used in P4
//  with JSON-schema validators. Run BEFORE seed_posts.js.
//
//  Collections:
//    social_posts     — polymorphic: instagram / tiktok / youtube subtypes
//    daily_metrics    — daily snapshots of views / likes / shares / etc.
//    comments         — comments per post, with a sentiment field
//    conversions      — post_id → converted student_id (denormalised ref to PG)
//
//  Each platform carries different fields:
//    Instagram : post_type ('reel'|'carousel'|'story'), duration_seconds, slides_count
//    TikTok    : post_type ('video'|'duet'|'stitch'), sound_id, sound_title,
//                duet_with, stitch_with, duration_seconds
//    YouTube   : video_id, duration_seconds, chapters[], watch_time_seconds_avg
// ============================================================================

db = db.getSiblingDB('afordchess');
['social_posts','daily_metrics','comments','conversions'].forEach(c => db.getCollection(c).drop());  // re-runnable

// 1) social_posts ------------------------------------------------------------
db.createCollection('social_posts', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['platform', 'external_id', 'posted_at', 'caption'],
      properties: {
        platform:   { enum: ['instagram', 'tiktok', 'youtube'] },
        external_id: { bsonType: 'string' },
        posted_at:   { bsonType: 'date' },
        caption:     { bsonType: 'string' },
        external_url:{ bsonType: 'string' },
        course_id:   { bsonType: ['int', 'null'] },
        tags:        { bsonType: 'array', items: { bsonType: 'string' } },
        instagram: {
          bsonType: ['object', 'null'],
          required: ['post_type'],
          properties: {
            post_type:        { enum: ['reel', 'carousel', 'story'] },
            duration_seconds: { bsonType: ['int', 'null'] },
            slides_count:     { bsonType: ['int', 'null'] },
            filter_used:      { bsonType: ['string', 'null'] }
          }
        },
        tiktok: {
          bsonType: ['object', 'null'],
          required: ['post_type'],
          properties: {
            post_type:        { enum: ['video', 'duet', 'stitch'] },
            sound_id:         { bsonType: ['string', 'null'] },
            sound_title:      { bsonType: ['string', 'null'] },
            duet_with:        { bsonType: ['string', 'null'] },
            stitch_with:      { bsonType: ['string', 'null'] },
            duration_seconds: { bsonType: ['int', 'null'] }
          }
        },
        youtube: {
          bsonType: ['object', 'null'],
          required: ['video_id'],
          properties: {
            video_id:               { bsonType: 'string' },
            duration_seconds:       { bsonType: ['int', 'null'] },
            chapters: {
              bsonType: ['array', 'null'],
              items: {
                bsonType: 'object',
                required: ['title', 'start_seconds'],
                properties: {
                  title:         { bsonType: 'string' },
                  start_seconds: { bsonType: 'int' }
                }
              }
            },
            watch_time_seconds_avg: { bsonType: ['int', 'null'] }
          }
        }
      }
    }
  },
  validationLevel: 'strict',
  validationAction: 'error'
});

// 2) daily_metrics -----------------------------------------------------------
db.createCollection('daily_metrics', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['post_id', 'date', 'platform', 'views', 'likes', 'comments', 'shares'],
      properties: {
        post_id:   { bsonType: 'objectId' },
        platform:  { enum: ['instagram', 'tiktok', 'youtube'] },
        date:      { bsonType: 'date' },
        views:     { bsonType: 'int' },
        likes:     { bsonType: 'int' },
        comments:  { bsonType: 'int' },
        shares:    { bsonType: 'int' },
        saves:     { bsonType: 'int' },
        instagram: {
          bsonType: ['object', 'null'],
          properties: {
            reach:          { bsonType: ['int', 'null'] },
            impressions:    { bsonType: ['int', 'null'] },
            profile_visits: { bsonType: ['int', 'null'] }
          }
        },
        tiktok: {
          bsonType: ['object', 'null'],
          properties: {
            for_you_impressions: { bsonType: ['int', 'null'] },
            duets_created:        { bsonType: ['int', 'null'] },
            stitches_created:     { bsonType: ['int', 'null'] }
          }
        },
        youtube: {
          bsonType: ['object', 'null'],
          properties: {
            watch_time_minutes:         { bsonType: ['int', 'null'] },
            avg_view_duration_seconds:  { bsonType: ['int', 'null'] },
            ctr:                         { bsonType: ['double', 'null'] }
          }
        }
      }
    }
  },
  validationLevel: 'strict',
  validationAction: 'error'
});

// 3) comments ----------------------------------------------------------------
db.createCollection('comments', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['post_id', 'platform', 'author', 'text', 'posted_at'],
      properties: {
        post_id:    { bsonType: 'objectId' },
        platform:   { enum: ['instagram', 'tiktok', 'youtube'] },
        external_id:{ bsonType: 'string' },
        author:     { bsonType: 'string' },
        text:       { bsonType: 'string' },
        posted_at:  { bsonType: 'date' },
        sentiment:  { enum: ['positive', 'neutral', 'negative'] }
      }
    }
  },
  validationLevel: 'strict',
  validationAction: 'error'
});

// 4) conversions -------------------------------------------------------------
db.createCollection('conversions', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['post_id', 'platform', 'converted_at'],
      properties: {
        post_id:               { bsonType: 'objectId' },
        platform:              { enum: ['instagram', 'tiktok', 'youtube'] },
        converted_student_id:  { bsonType: ['int', 'null'] },   // ref to PG students
        converted_at:          { bsonType: 'date' },
        revenue_usd_equiv:     { bsonType: ['double', 'null'] }
      }
    }
  },
  validationLevel: 'strict',
  validationAction: 'error'
});

print('==> Collections created: social_posts, daily_metrics, comments, conversions');
printjson(db.getCollectionNames());

