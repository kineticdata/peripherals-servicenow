{
  'info' => {
    'api_username' => "kinetic_integration_user",
    'api_password' => "iMEPYxkmYyMaAgRNTz3ffpup",
    'api_location' => "https://dev74805.service-now.com",
    'enable_debug_logging' => 'true'
  },
  'parameters' => {
    'error_handling' => 'Error Message',
    'method' => 'POST',
    'path' => '/api/now/table/incident',
    'body' => '{"caller_id":"matthew.howe@kineticdata.com","short_description":"Problem with my computer."}'
  }
}
