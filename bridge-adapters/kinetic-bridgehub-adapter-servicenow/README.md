# Service Now Bridgehub Adapter
This bridge adapter is used for setting up bridges to interact with Service Now instances.

## Configuration Values

| Name                    | Description | Example Value |
| :---------------------- | :------------------------- | :------------------------- |
| Username                | The username that will be used to access the sNow instance | user@acme.com |
| Password                | The password that is associated with the username | secret-password |
| ServiceNow Instance     | The url of the sNow instance up to and including the instance name | https://dev55555.service-now.com |

## Supported Structures
| Name | Description |
| :---------------------- | :------------------------- |
| ${table_name} | Any table available in the Service Now instance that can be accessed through _/api/now/table/${table_name}_ |

## Attributes and Fields
* If no fields are provided then all fields will be returned.

## Qualifications (Query)
* This adapter supports only queries to the [Service Now v1 table api](https://docs.servicenow.com/bundle/sandiego-application-development/page/integrate/inbound-rest/concept/c_TableAPI.html#table-GET). 

