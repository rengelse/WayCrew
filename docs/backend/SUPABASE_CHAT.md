# Supabase Chat – v0.2.4

## Tables

- `chats`: one chat attached to either an activity or a group.
- `chat_members`: server-maintained access list. Clients cannot add themselves directly.
- `messages`: persistent chat messages.

## Membership

Activity chat access is granted only to participants with `approved` or `active` status. Requested/invited users do not receive chat access.

Group chat access is granted only to group members with `active` status.

Database triggers keep `chat_members` synchronized when activity/group membership or roles change.

## Realtime

`public.messages` is added to the `supabase_realtime` publication. Flutter subscribes using the Supabase table stream filtered by `chat_id`, so inserts are rendered without manual refresh.

## Security

RLS requires `chat_members` membership for reading chats, chat members and messages. Normal clients may insert only their own non-system messages. An `important=true` message requires activity-leader or group-admin permission.

System messages are represented in the schema but are reserved for server-side/event generation in a later milestone.
