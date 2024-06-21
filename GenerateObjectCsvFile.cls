public with sharing class GenerateObjectCsvFile {

    static String separator=';';
    static String columnDelimiter='"';


    static List<String> csvHeaders =new List<String>();
    static List<String> soqlColumn =new List<String>();


    public static void generateFile(String sObjectApiName,Datetime lastExport,String fileTitle){
        createCSV(getResult(sObjectApiName,lastExport),fileTitle);
    }

    public static String generateSoqlQuery(String sObjectApiName,Datetime lastExport){
        for(FieldDefinition fieldDef : [SELECT QualifiedApiName   FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName =:sObjectApiName AND IsCalculated = false]){
            csvHeaders.add(columnDelimiter+fieldDef.QualifiedApiName+columnDelimiter);
            soqlColumn.add(fieldDef.QualifiedApiName);
        }

        return 'SELECT '+String.join(soqlColumn,',')+' FROM '+sObjectApiName +' WHERE LastModifiedDate >:lastExport ALL ROWS';
    }


    public static List<Sobject> getResult(String sObjectApiName,Datetime lastExport){
        String soqlQuery=generateSoqlQuery(sObjectApiName,lastExport);
        return Database.query(soqlQuery);
    }



    public static void createCSV(List<sObject> csvRowList, String title){
        String headerRow = String.join(csvHeaders,separator) + '\n';
        String concantenatedStr = headerRow;
        concantenatedStr = createSObjectString(soqlColumn, csvRowList, concantenatedStr);
        title += '.csv';
        createFile(concantenatedStr, title);
    }

    private static String createSObjectString(List<String> csvFieldAPINames, List<sObject> csvRowList, String concantenatedStr){
        Integer i = 0;
        Integer rowListSize = csvRowList.size();
        Integer headerSize = csvFieldAPINames.size();
        for(sObject row :csvRowList){
            //assuming the rowList is in the correct format and each string in the list is a new record
            Map<String, Object> objFieldMap = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(row));
            Integer j = 0;
            for(String objField :csvFieldAPINames){
                concantenatedStr += objFieldMap.get(objField) != null ? columnDelimiter+String.valueOf(objFieldMap.get(objField))+columnDelimiter :columnDelimiter+ ''+columnDelimiter;
                j++;
                concantenatedStr += j != headerSize ? separator : '';//add comma separator
            }
            i++;
            if(i != rowListSize) concantenatedStr += '\n';//add new line
        }
        return concantenatedStr;
    }


    public static void createFile(String versionData, String title) {
        ContentVersion cv = new ContentVersion();
        cv.ContentLocation = 'S'; //denotes it resides on Salesforce
        cv.Title = title; //title of the file
        cv.PathOnClient = title; // full path within Salesforce this can just be the name of file to be in the library
        cv.VersionData = Blob.valueOf(versionData); //file data
        insert cv;
        createContentDistribution(cv);
    }


    private static void createContentDistribution(ContentVersion cv){
        ContentDistribution newDist = new ContentDistribution();
        newDist.ContentVersionId = cv.Id;
        newDist.Name = cv.Title+' external link';
        newDist.PreferencesNotifyOnVisit = false;
        newDist.PreferencesAllowViewInBrowser = true;
        newDist.PreferencesAllowOriginalDownload=true;
        insert newDist;
    } 
}
