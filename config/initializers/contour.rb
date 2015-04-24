# Use to configure basic appearance of template
Contour.setup do |config|

  # Enter your application name here. The name will be displayed in the title of all pages, ex: AppName - PageTitle
  config.application_name = ENV['website_name']

  # If you want to style your name using html you can do so here, ex: <b>App</b>Name
  # config.application_name_html = ''

  # Enter your application version here. Do not include a trailing backslash. Recommend using a predefined constant
  config.application_version = TaskTracker::VERSION::STRING

  # Enter your application header background image here.
  config.header_background_image = ''

  # Enter your application header title image here.
  # config.header_title_image = 'stylefile.png'

  # Enter the items you wish to see in the menu
  config.menu_items = [
    {
      name: 'Sign Up', display: 'not_signed_in', path: 'new_user_registration_path', position: 'right'
    },
    {
      name: 'image_tag(current_user.avatar_url(18, "blank"))+" "+current_user.name', eval: true, display: 'signed_in', path: 'settings_path', position: 'right',
      links: [{ name: "About #{ENV['website_name']} v#{TaskTracker::VERSION::STRING}", path: 'about_path' },
              { divider: true },
              { header: 'Administrative', condition: 'current_user.system_admin?' },
              { name: 'Users', path: 'users_path', condition: 'current_user.system_admin?' },
              { divider: true, condition: 'current_user.system_admin?' },
              { header: 'current_user.email', eval: true },
              { name: 'Settings', path: 'settings_path' },
              { divider: true },
              { name: 'Logout', path: 'destroy_user_session_path' }]
    },
    {
      name: 'Projects', display: 'signed_in', path: 'projects_path', position: 'left',
      links: [{ name: 'Create', path: 'new_project_path' }]
    },
    {
      name: 'My Tasks', display: 'signed_in', path: 'tasks_path( owners: current_user.name )', position: 'left',
      links: [
                { name: 'Day',    path: 'day_path( owners: current_user.name )'   },
                { name: 'Week',   path: 'week_path( owners: current_user.name )'  },
                { name: 'Month',  path: 'month_path( owners: current_user.name )' },
                { name: 'Stats', path: 'stats_path' },
              ]
    }
  ]

  # Enter search bar information if you would like one [default none]:
  config.search_bar = {
    display: 'signed_in',
    id: 'global-search',
    path: 'search_path',
    placeholder: 'Search',
    position: 'left'
  }

  # Enter an address of a valid RSS Feed if you would like to see news on the sign in page.
  # config.news_feed = ''

  # Enter the max number of items you want to see in the news feed.
  # config.news_feed_items = 3

  # An array of hashes that specify additional fields to add to the sign up form
  # An example might be [ { attribute: 'first_name', type: 'text_field' }, { attribute: 'last_name', type: 'text_field' } ]
  config.sign_up_fields = [ { attribute: 'first_name', type: 'text_field' }, { attribute: 'last_name', type: 'text_field' } ]

  # An array of text fields used to trick spam bots using the honeypot approach. These text fields will not be displayed to the user.
  # An example might be [ :url, :address, :contact, :comment ]
  config.spam_fields = [ :url, :address, :contact, :comment ]
end
