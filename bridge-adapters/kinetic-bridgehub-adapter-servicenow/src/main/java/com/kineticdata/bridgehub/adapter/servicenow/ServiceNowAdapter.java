package com.kineticdata.bridgehub.adapter.servicenow;

import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.BridgeUtils;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import com.kineticdata.commons.v1.config.ConfigurableProperty;
import com.kineticdata.commons.v1.config.ConfigurablePropertyMap;
import java.io.IOException;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;
import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.slf4j.LoggerFactory;

public class ServiceNowAdapter implements BridgeAdapter {
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/

    /** Defines the adapter display name */
    public static final String NAME = "ServiceNow Bridge";

    /** Defines the logger */
    protected static final org.slf4j.Logger logger = LoggerFactory.getLogger(ServiceNowAdapter.class);

    /** Adapter version constant. */
    public static String VERSION;
    /** Load the properties version from the version.properties file. */
    static {
        try {
            java.util.Properties properties = new java.util.Properties();
            properties.load(ServiceNowAdapter.class.getResourceAsStream("/"+ServiceNowAdapter.class.getName()+".version"));
            VERSION = properties.getProperty("version");
        } catch (IOException e) {
            logger.warn("Unable to load "+ServiceNowAdapter.class.getName()+" version properties.", e);
            VERSION = "Unknown";
        }
    }

    /** Defines the collection of property names for the adapter */
    public static class Properties {
        public static final String USERNAME = "Username";
        public static final String PASSWORD = "Password";
        public static final String INSTANCE = "ServiceNow Instance";
    }

    private final ConfigurablePropertyMap properties = new ConfigurablePropertyMap(
        new ConfigurableProperty(Properties.USERNAME).setIsRequired(true),
        new ConfigurableProperty(Properties.PASSWORD).setIsRequired(true).setIsSensitive(true),
        new ConfigurableProperty(Properties.INSTANCE).setIsRequired(true)
    );

    private String username;
    private String password;
    private String instance;

    /*---------------------------------------------------------------------------------------------
     * SETUP METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public void initialize() throws BridgeError {
        this.username = properties.getValue(Properties.USERNAME);
        this.password = properties.getValue(Properties.PASSWORD);
        this.instance = properties.getValue(Properties.INSTANCE);
        testAuth(this.instance);
    }

    @Override
    public String getName() {
        return NAME;
    }

    @Override
    public String getVersion() {
        return VERSION;
    }

    @Override
    public void setProperties(Map<String,String> parameters) {
        properties.setValues(parameters);
    }

    @Override
    public ConfigurablePropertyMap getProperties() {
        return properties;
    }

    /*---------------------------------------------------------------------------------------------
     * IMPLEMENTATION METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public Count count(BridgeRequest request) throws BridgeError {
        String structure = request.getStructure();

        ServiceNowQualificationParser parser = new ServiceNowQualificationParser();
        String query = parser.parse(request.getQuery(),request.getParameters());
        String url = String.format("%s/api/now/stats/%s?sysparm_count=true&sysparm_query=%s", this.instance, structure, URLEncoder.encode(query));

        HttpClient client = HttpClients.createDefault();
        HttpGet get = new HttpGet(url);
        String credentials = String.format("%s:%s", this.username, this.password);
        byte[] basicAuthBytes = Base64.encodeBase64(credentials.getBytes());
        get.setHeader("Authorization", "Basic " + new String(basicAuthBytes));
        get.setHeader("Content-Type", "application/json");

        HttpResponse response;
        String output = "";

        try {
            response = client.execute(get);
            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
        }
        catch (IOException e) {
            throw new BridgeError("Unable to make a connection to properly execute the"
                    + "query to ServiceNow");
        }

        Long count;
        JSONObject jsonOutput = (JSONObject)JSONValue.parse(output);

        if (jsonOutput.get("error") != null) {
            JSONObject error = (JSONObject) jsonOutput.get("error");
            logger.error("Error: " + error.get("message"));
            String errorMessage = (String) error.get("message");
            throw new BridgeError(errorMessage);
        }
        else {
            JSONObject stats = (JSONObject) jsonOutput.get("result");
            JSONObject outputCount = (JSONObject) stats.get("stats");
            count = Long.valueOf(outputCount.get("count").toString());
        }

        return new Count(count);
    }

    @Override
    public Record retrieve(BridgeRequest request) throws BridgeError {
        ServiceNowQualificationParser parser = new ServiceNowQualificationParser();
        String query = parser.parse(request.getQuery(),request.getParameters());
        List<String> fields = request.getFields();
        String joinedFields;

        if (fields != null) {
            joinedFields = StringUtils.join(fields,",");
        }
        else {
            joinedFields = ""; // if fields not entered, returns all fields
        }

        String structure = request.getStructure();

        StringBuilder queryBuilder = new StringBuilder();
        queryBuilder.append(String.format("%s/api/now/v1/table/%s?sysparm_fields=%s&sysparm_query=%s", this.instance, structure, joinedFields, URLEncoder.encode(query)));

        HttpClient client = HttpClients.createDefault();
        HttpGet get = new HttpGet(queryBuilder.toString());
        String credentials = String.format("%s:%s", this.username, this.password);
        byte[] basicAuthBytes = Base64.encodeBase64(credentials.getBytes());
        get.setHeader("Authorization", "Basic " + new String(basicAuthBytes));
        get.setHeader("Content-Type", "application/json");

        HttpResponse response;
        String output = "";

        try {
            response = client.execute(get);
            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
        }
        catch (IOException e) {
            throw new BridgeError("Unable to make a connection to properly execute the"
                    + "query to ServiceNow");
        }

        JSONObject jsonOutput = (JSONObject)JSONValue.parse(output);
        //Map<String,Object> record = new LinkedHashMap<>();
        Record record;

        if (jsonOutput.get("error") != null) {
            JSONObject error = (JSONObject) jsonOutput.get("error");
            logger.error("Error: " + error.get("message"));
            String errorMessage = (String) error.get("message");
            throw new BridgeError(errorMessage);
        }
        else {
            JSONArray results = (JSONArray)jsonOutput.get("result");

            if (results.size() > 1) {
                throw new BridgeError("Multiple results matched an expected single match query");
            } else if (results.isEmpty()) {
                record = new Record(null);
            } else {
                JSONObject result = (JSONObject)results.get(0);
                Map<String,Object> recordMap = new LinkedHashMap<String,Object>();
                if (fields == null) { fields = new ArrayList( result.entrySet()); }
                for (String field : fields) {
                    recordMap.put(field, result.get(field));
                }
                record = new Record(recordMap);
            }
        }

        return record;
    }

    @Override
    public RecordList search(BridgeRequest request) throws BridgeError {
        ServiceNowQualificationParser parser = new ServiceNowQualificationParser();
        String query = parser.parse(request.getQuery(),request.getParameters());
        List<String> fields;
        String joinedFields;
        String structure = request.getStructure();
        StringBuilder queryBuilder = new StringBuilder();

        if (request.getFields() != null) {
            fields = request.getFields();
            joinedFields = StringUtils.join(fields,",");
        }
        else {
            fields = null;
            joinedFields = ""; // if fields not entered, returns all fields
        }

        Map<String,String> metadata = BridgeUtils.normalizePaginationMetadata(request.getMetadata());

        // Creating a order by string to add to the jql query.
        List<String> orderList = new ArrayList();
        String order = new String();

        // Id and Key are considered aliases but have different values, so
        // if one is added the other won't be added so that an error is not thrown.
        Boolean keyAppended = false;

        if (request.getMetadata("order") != null) {
            for (Map.Entry<String,String> entry : BridgeUtils.parseOrder(request.getMetadata("order")).entrySet()) {
                String key = entry.getKey();
                if (!((key.equals("key") || key.equals("id")) && keyAppended == true)) {
                    if (key.equals("key") || key.equals("id")) {
                        keyAppended = true;
                    }
                    if (entry.getValue().equals("DESC")) {
                        orderList.add("^ORDERBYDESC" + key);
                    }
                    else {
                        orderList.add("^ORDERBY" + key);
                    }
                }
            }
            order = StringUtils.join(orderList,",");
        }

        queryBuilder.append(String.format("%s/api/now/v1/table/%s?sysparm_fields=%s&sysparm_query=%s%s", this.instance, structure, joinedFields, URLEncoder.encode(query), URLEncoder.encode(order)));
        queryBuilder.append("&sysparm_limit=").append(metadata.get("pageSize"));
        queryBuilder.append("&sysparm_offset=").append(metadata.get("offset"));

        HttpClient client = HttpClients.createDefault();
        HttpGet get = new HttpGet(queryBuilder.toString());
        String credentials = String.format("%s:%s", this.username, this.password);
        byte[] basicAuthBytes = Base64.encodeBase64(credentials.getBytes());
        get.setHeader("Authorization", "Basic " + new String(basicAuthBytes));
        get.setHeader("Content-Type", "application/json");

        HttpResponse response;
        String output = "";

        try {
            response = client.execute(get);
            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
        }
        catch (IOException e) {
            throw new BridgeError("Unable to make a connection to properly execute the"
                    + "query to ServiceNow");
        }

        JSONArray jsonArray;
        JSONObject jsonOutput = (JSONObject)JSONValue.parse(output);
        ArrayList<Record> records = new ArrayList<Record>();

        if (jsonOutput.get("error") != null) {
            JSONObject error = (JSONObject)jsonOutput.get("error");
            logger.error("Error: " + error.get("message"));
            String errorMessage = (String)error.get("message");
            throw new BridgeError(errorMessage);
        }
        else {
            jsonArray = (JSONArray)jsonOutput.get("result");

            for (int i=0; i < jsonArray.size(); i++) {
                JSONObject recordObject = (JSONObject)jsonArray.get(i);
                records.add(new Record((Map<String,Object>)recordObject));
            }

            // If fields is null, all fields are returned. Get the first element
            // of the returned objects and get its fields.
            if (fields == null ) {
                fields = new ArrayList<String>();
                JSONObject firstObject = (JSONObject)jsonArray.get(0);
                Iterator allFields = firstObject.entrySet().iterator();
                while ( allFields.hasNext() ) {
                    Map.Entry pair = (Map.Entry)allFields.next();
                    fields.add(pair.getKey().toString());
                }
            }
        }

        metadata.put("count",String.valueOf(records.size()));
        metadata.put("size", String.valueOf(records.size()));

        return new RecordList(fields, records, metadata);
    }

    /*----------------------------------------------------------------------------------------------
     * PRIVATE HELPER METHODS
     *--------------------------------------------------------------------------------------------*/

    private void testAuth(String instance) throws BridgeError {
        logger.debug("Testing the authentication credentials");
        HttpGet get = new HttpGet(String.format("%s/api/now/v1/table/sys_user?sysparm_limit=1", instance));
        get = addAuthenticationHeader(get, this.username, this.password);

        HttpClient client = HttpClients.createDefault();
        HttpResponse response;
        try {
            response = client.execute(get);
            HttpEntity entity = response.getEntity();
            EntityUtils.consume(entity);
            if (response.getStatusLine().getStatusCode() == 401) {
                throw new BridgeError("Unauthorized: The inputted Username/Password combination is not valid.");
            }
        }
        catch (IOException e) {
            logger.error(e.getMessage());
            throw new BridgeError("Unable to make a connection to properly to ServiceNow.");
        }
    }

    private HttpGet addAuthenticationHeader(HttpGet get, String username, String password) {
        String creds = username + ":" + password;
        byte[] basicAuthBytes = Base64.encodeBase64(creds.getBytes());
        get.setHeader("Authorization", "Basic " + new String(basicAuthBytes));

        return get;
    }

}