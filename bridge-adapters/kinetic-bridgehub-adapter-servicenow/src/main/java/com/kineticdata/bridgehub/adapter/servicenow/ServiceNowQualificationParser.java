package com.kineticdata.bridgehub.adapter.servicenow;

import com.kineticdata.bridgehub.adapter.QualificationParser;

public class ServiceNowQualificationParser extends QualificationParser {
    public String encodeParameter(String name, String value) {
        return value;
    }
}
