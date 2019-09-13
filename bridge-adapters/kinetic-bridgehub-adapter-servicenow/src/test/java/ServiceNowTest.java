import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeAdapterTestBase;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import com.kineticdata.bridgehub.adapter.servicenow.ServiceNowAdapter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.apache.http.NameValuePair;
import org.apache.http.message.BasicNameValuePair;
import static org.junit.Assert.assertEquals;
import org.junit.Test;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

public class ServiceNowTest extends BridgeAdapterTestBase{
        
    @Override
    public Class getAdapterClass() {
        return ServiceNowAdapter.class;
    }
    
    @Override
    public String getConfigFilePath() {
        return "src/test/resources/bridge-config.yml";
    }
    
    @Test
    public void test_count() throws Exception{
        BridgeError error = null;

        BridgeRequest request = new BridgeRequest();
        
        List<String> fields = Arrays.asList("short_description");
        request.setFields(fields);
        
        request.setStructure("incident");
        request.setFields(fields);
        request.setQuery("");
        
        Count count = null;
        try {
            count = getAdapter().count(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(count.getValue() > 0);
    }
    
    @Test
    public void test_search() throws Exception{
        BridgeError error = null;
        
        assertNull(error);
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("short_description");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("incident");
        request.setFields(fields);
        request.setQuery("");
        
        RecordList list = null;
        try {
            list = getAdapter().search(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(list.getRecords().size() > 0);
    }
    
    @Test
    public void test_search_query() throws Exception{
        BridgeError error = null;
        
        assertNull(error);
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("email");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("sys_user");
        request.setFields(fields);
        request.setQuery("last_name=Bonnet");
        
        RecordList list = null;
        try {
            list = getAdapter().search(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(list.getRecords().size() > 0);
    }
}
