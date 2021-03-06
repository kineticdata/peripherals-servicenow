# ServiceNow API V1
ServiceNow API V1

## Parameters
[Error Handling]
  Select between returning an error message, or raising an exception.

[Method]
  HTTP Method to use for the SericeNow API call being made.
  Options are:
    - GET
    - POST
    - PUT
    - PATCH
    - DELETE

[Path]
  The relative API path (to the `api_location` info value) that will be called.
  This value should begin with a forward slash `/`.

[Body]
  The body content (JSON) that will be sent for POST, PUT, and PATCH requests.

## Results
[Response Code]
  The returned code from the Rest Call (Example: 200)
  
[Response Body]
  The returned value from the Rest Call (JSON format)
