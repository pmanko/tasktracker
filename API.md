## Task Tracker API

The Task Tracker uses a RESTFUL API common to Rails applications. Responses are returned as JSON objects.

### Tasks

POST with JSON STRING (preferred)

```console
curl -u username:password \
  -H 'WWW-Authenticate: Basic realm="Application"' \
  -H 'Content-Type: application/json' \
  -d '{ "project_id":"3", "unassigned": "1", "status[]": ["completed", "planned"], "tag_filter": "any", "tag_names[]": [], "search": "", "order": "stickies.due_date DESC" }' \
  http://localhost/stickies.json
```

Other Options

```
due_date_start_date  (format mm/dd/yy or mm/dd/yyyy)
due_date_end_date
owner_id  (users have their own id in the system)
```

Using plain parameters

Simple POST with PARAM STRING

```console
curl -u username:password \
  -H 'WWW-Authenticate: Basic realm="Application"' \
  -d 'project_id=3&unassigned=1&status[]=completed&status=planned&tag_filter=any&tag_names[]=&search=&order=stickies.due_date+DESC' \
  http://localhost/stickies.json
```


Success will return you the tasks JSON object

```json
[
  {
    "all_day": true,
    "completed": false,
    "created_at": "2012-06-13T15:46:12-04:00",
    "description": "Mow the Lawn",
    "due_date": "2012-06-29T00:00:00-04:00",
    "duration": 0,
    "duration_units": "hours",
    "board_id": null,
    "group_id": 683,
    "id": 6352,
    "owner_id": 2,
    "project_id": 3,
    "updated_at": "2012-07-09T11:04:08-04:00",
    "user_id": 2,
    "group_description": "Fourth Week of June",
    "sticky_link": "http://localhost/tasktracker/stickies/6352",
    "tags": [
      {
        "color": "#fcda00",
        "created_at": "2012-06-01T14:53:35-04:00",
        "deleted": false,
        "description": "",
        "id": 92,
        "name": "Chore",
        "project_id": 3,
        "updated_at": "2012-06-01T14:53:35-04:00",
        "user_id": 1
      }
    ]
  },
  {
    ...
  }
]
```

### Projects

GET with PARAM STRING

```console
curl -u username:password \
  -H 'WWW-Authenticate: Basic realm="Application"' \
  -H 'Content-Type: application/json' \
  http://localhost/projects.json?search=
```

Success will return a JSON array of projects

```json
[
  {
    "created_at": "2011-02-25T14:01:04-05:00",
    "description": "This project lets me organize my chores.",
    "end_date": "2012-12-31",
    "id": 2,
    "name": "My Chores",
    "start_date": "2011-02-25",
    "updated_at": "2012-08-20T13:31:26-04:00",
    "user_id": 1,
    "project_link": "http://localhost/projects/2",
    "color": "#43d691"
  },
  {
    ...
  }
]
```

### Signing In

POST with PARAM STRING

```console
curl -d 'user[email]=email@example.com&user[password]=password' http://localhost/users/login.json
```

Success will return a JSON hash with user details:

```json
{
  "success": true,
  "user":
    {
      "id": 1,
      "email": "email@example.com",
      "first_name": "Joe",
      "last_name": "Schmoe",
      "authentication_token": "abc123"
    }
}
```
