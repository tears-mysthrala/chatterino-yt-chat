local Moderation = {}

function Moderation.deleted(target_message_id, actor_name)
  return {
    kind = "moderation_deleted",
    target_message_id = target_message_id,
    actor = actor_name
  }
end

function Moderation.timed_out(author_external_channel_id, duration_sec)
  return {
    kind = "moderation_timeout",
    author_channel_id = author_external_channel_id,
    duration_sec = duration_sec
  }
end

function Moderation.ban(author_external_channel_id)
  return {
    kind = "moderation_hide_user",
    author_channel_id = author_external_channel_id
  }
end

return Moderation
