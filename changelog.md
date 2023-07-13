ServiceNow \[bridge adapters\] (2019-09-13)
  * \[kinetic-bridgehub-adapter-servicenow\] (2019-09-13)
    * added Test suite
    * bugfix PER-166 sysparm_limit issue
    * added changelog file.

ServiceNow \[handlers\] (2021-01-24)
  * \[servicenow_api_v1\] 
    * initial commit of new handler

ServiceNow [bridge adapters] (2022-07-03)
  * \[kinetic-bridgehub-adapter-servicenow\]
    * updated to use aws remote repo from nexus
    * replaced kinetic-bridgehub-adapter dependency with kinetic-agent-adapter dependency
    * Added dependency for testing

ServiceNow \[bridge adapters\] and \[handlers\] (2023-07-13)
  * \[kinetic-bridgehub-adapter-servicenow\]
    * bumped version of slf4j-api from 1.7.10 to 1.7.36
    * bumped version of httpclient from 4.5.1 to 4.5.14
    * versioned bridge adapter to v1.0.4
  * \[servicenow_api_v1\]
    * added extra logic to handler empty body responses .
