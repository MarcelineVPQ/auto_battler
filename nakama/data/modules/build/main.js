"use strict";
const LEADERBOARD_ID = "elo_ratings";
const ELO_DEFAULT = 1000;
const SQUAD_COLLECTION = "squad_snapshots";
const SQUAD_KEY = "current";
function InitModule(ctx, logger, nk, initializer) {
    // Create ELO leaderboard (set operator = best keeps the latest submitted score)
    nk.leaderboardCreate(LEADERBOARD_ID, false, "descending" /* nkruntime.SortOrder.DESCENDING */, "set" /* nkruntime.Operator.SET */);
    logger.info("ELO leaderboard created/verified: %s", LEADERBOARD_ID);
    initializer.registerRpc("find_opponents", findOpponents);
    initializer.registerRpc("record_result", recordResult);
    logger.info("Auto Battler Nakama module loaded.");
}
// ── find_opponents RPC ──────────────────────────────────────────────
// Input:  { "rating": int, "round": int, "range": int }
// Output: Array of opponent snapshots sorted by rating proximity.
function findOpponents(ctx, logger, nk, payload) {
    const input = JSON.parse(payload);
    const rating = input.rating || ELO_DEFAULT;
    const range = input.range || 200;
    const callerId = ctx.userId;
    // Query leaderboard for players near this rating.
    // Nakama leaderboard scores are integers. We query around the target rating.
    const minScore = rating - range;
    const maxScore = rating + range;
    // List leaderboard records around the caller's rank.
    // We fetch a generous window and filter client-side.
    let records = [];
    try {
        // Try to list around the caller's own record first
        const result = nk.leaderboardRecordsList(LEADERBOARD_ID, [callerId], 50, undefined, 0);
        if (result.records) {
            records = result.records;
        }
    }
    catch (e) {
        // Caller may not have a record yet — list from the top
        logger.warn("Leaderboard list around caller failed, listing from top: %s", e);
    }
    if (records.length === 0) {
        try {
            const result = nk.leaderboardRecordsList(LEADERBOARD_ID, [], 50, undefined, 0);
            if (result.records) {
                records = result.records;
            }
        }
        catch (e) {
            logger.error("Failed to list leaderboard: %s", e);
            return JSON.stringify([]);
        }
    }
    // Filter: within range, exclude self
    const candidates = records.filter(r => {
        if (r.ownerId === callerId)
            return false;
        const score = r.score ?? ELO_DEFAULT;
        return score >= minScore && score <= maxScore;
    });
    // Fetch squad snapshots for each candidate
    const opponents = [];
    for (const rec of candidates) {
        try {
            const objs = nk.storageRead([{
                    collection: SQUAD_COLLECTION,
                    key: SQUAD_KEY,
                    userId: rec.ownerId,
                }]);
            if (objs.length > 0) {
                const snap = objs[0].value;
                opponents.push({
                    player_id: rec.ownerId,
                    player_name: rec.username ?? ("Player_" + rec.ownerId.substring(0, 4).toUpperCase()),
                    rating_at_time: rec.score ?? ELO_DEFAULT,
                    squad_json: snap.squad_json || [],
                    squad_size: snap.squad_size || 0,
                    total_dps: snap.total_dps || 0,
                    round_number: snap.round_number || 1,
                });
            }
        }
        catch (e) {
            logger.warn("Failed to read squad snapshot for %s: %s", rec.ownerId, e);
        }
    }
    // Sort by rating proximity to caller
    opponents.sort((a, b) => {
        return Math.abs(a.rating_at_time - rating) - Math.abs(b.rating_at_time - rating);
    });
    // Return up to 9 opponents
    return JSON.stringify(opponents.slice(0, 9));
}
// ── record_result RPC ───────────────────────────────────────────────
// Input:  { "new_rating": int, "won": bool }
// Atomically updates ELO leaderboard + win/loss metadata.
function recordResult(ctx, logger, nk, payload) {
    const input = JSON.parse(payload);
    const newRating = input.new_rating || ELO_DEFAULT;
    const won = input.won === true;
    const userId = ctx.userId;
    const username = ctx.username;
    // Write leaderboard score (SET operator — overwrites with new ELO)
    nk.leaderboardRecordWrite(LEADERBOARD_ID, userId, username, newRating);
    // Read current win/loss metadata from storage
    const STATS_COLLECTION = "player_stats";
    const STATS_KEY = "record";
    let wins = 0;
    let losses = 0;
    try {
        const objs = nk.storageRead([{
                collection: STATS_COLLECTION,
                key: STATS_KEY,
                userId: userId,
            }]);
        if (objs.length > 0) {
            const stats = objs[0].value;
            wins = stats.wins || 0;
            losses = stats.losses || 0;
        }
    }
    catch (e) {
        logger.warn("Could not read player stats for %s: %s", userId, e);
    }
    if (won) {
        wins += 1;
    }
    else {
        losses += 1;
    }
    // Write updated stats
    nk.storageWrite([{
            collection: STATS_COLLECTION,
            key: STATS_KEY,
            userId: userId,
            value: { wins: wins, losses: losses, rating: newRating },
            permissionRead: 2, // public read
            permissionWrite: 0, // server-only write
        }]);
    logger.info("Recorded result for %s: rating=%d won=%s (W:%d L:%d)", userId, newRating, won, wins, losses);
    return JSON.stringify({ rating: newRating, wins: wins, losses: losses });
}
