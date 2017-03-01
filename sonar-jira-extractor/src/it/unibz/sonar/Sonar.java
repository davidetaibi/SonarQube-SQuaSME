package it.unibz.sonar;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

import java.io.*;
import java.lang.reflect.Array;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class Sonar {

    private static JSONParser parser = new JSONParser();

    public static void main(String[] args) {
        //ignore args for now
        final String projectKey = "cli";
        final String projectName = "CLI";
        final String metricsFile = "metrics.txt";
        final String codesmellsFile = "codesmells.txt";
        String dateParam = null;


        List<String> metricsDefined = readListFromFile(metricsFile);
        List<String> codesmellsDefined = readListFromFile(codesmellsFile);
        System.out.println(metricsDefined.size() + " metrics: " + Arrays.toString(metricsDefined.toArray()));
        System.out.println(codesmellsDefined.size() + " code smells: " + Arrays.toString(codesmellsDefined.toArray()));




        String fileOut = projectKey.replaceAll("\\.", "_").replaceAll(":", "_") + ".csv";
        try (BufferedWriter bw = new BufferedWriter(new FileWriter(fileOut))) {


            /// get data from sonarqube
            String timeMachineQuery = "http://sonar.inf.unibz.it/api/timemachine/index" +
                    "?resource=" + projectKey +
                    "&metrics=" + separatedByCommas(metricsDefined) +
                    ((dateParam == null)? "" : "&fromDateTime=" + dateParam);
            String sonarResult = getStringFromUrl(timeMachineQuery);

            JSONArray jsonArray = (JSONArray) parser.parse(sonarResult);
            // sonar returns array with just 1 element, this loop executes just once
            for(Object responseObj: jsonArray){
                if ( responseObj instanceof JSONObject ) {
                    JSONObject mainObject = (JSONObject) responseObj;
                    // for each sonar returned metric, add it to header
                    JSONArray colsArray = (JSONArray) mainObject.get("cols");
                    List<String> metricsReceived = new ArrayList<>();
                    for(Object colsItem: colsArray){
                        if ( colsItem instanceof JSONObject ) {
                            metricsReceived.add( ((JSONObject) colsItem).get("metric").toString() );
                        }
                    }
                    if (metricsReceived.size() != metricsDefined.size())
                        printMissingItems(metricsDefined, metricsReceived, "metrics");
                    String fileHeader = "Project,Date,"
                            + separatedByCommas(metricsReceived) + ","
                            + separatedByCommas(codesmellsDefined) + ","
                            + "Jira";
                    bw.write(fileHeader + "\n");

                    // for each sonar returned row (cell) of metrics values,
                    // add date, metrics, codesmells, jira issue count to it
                    JSONArray cellArray = (JSONArray) mainObject.get("cells");
                    for(Object cellItem: cellArray){
                        if ( cellItem instanceof JSONObject ) {
                            List<String> row = new ArrayList<>();
                            row.add(projectName);

                            String cellItemDate = ((JSONObject) cellItem).get("d").toString();
                            row.add(cellItemDate);

                            JSONArray cellMetricValues = (JSONArray) ((JSONObject) cellItem).get("v");
                            for(Object metricValue: cellMetricValues){
                                if ( metricValue == null)
                                    row.add("null");
                                else
                                    row.add(metricValue.toString().replace(",", ";"));
                            }

                            //now add codesmells
                            for(String rule: codesmellsDefined) {
                                String issueQuery="http://sonar.inf.unibz.it/api/issues/search" +
                                        "?componentKeys=" + projectKey +
                                        "&rules=" + rule +
                                        "&createdAt=" + URLEncoder.encode(cellItemDate,"UTF-8");
                                String issueResult = getStringFromUrl(issueQuery);
                                JSONObject issueResponse = (JSONObject) parser.parse(issueResult);
                                Object totalIssues = issueResponse.get("total");
                                row.add(totalIssues.toString());
                            }

                            //add jira BUG count for that day
                            String[] dateParts = cellItemDate.split("T"); //but this is the whole day :o
                            String dateForJira = dateParts[0];

                            String jiraQueryString = "https://issues.apache.org/jira/rest/api/2/search?jql=";
                            String jiraQueryPart = "project = " + projectName
                                    + " and issuetype = BUG"
                                    + " and created <= " + dateForJira;
                            jiraQueryString += URLEncoder.encode(jiraQueryPart,"UTF-8");
                            //issuetype = Bug AND resolved != null AND resolved < startOfMonth() AND status was Resolved BY Jsmith ORDER BY resolutiondate

                            String jiraResult = getStringFromUrl(jiraQueryString);
                            JSONObject jiraObj = (JSONObject) parser.parse(jiraResult);
                            row.add(jiraObj.get("total").toString());


                            // finally write row to file
                            bw.write(separatedByCommas(row) + "\n");
                        }
                    }
                }
            }
            System.out.println("Data saved to " + fileOut);
        } catch (IOException e) {
            System.out.println("Read/write error");
            e.printStackTrace();
        } catch (ParseException e) {
            System.out.println("JSON parsing error");
            e.printStackTrace();
        }

    }

    private static void printMissingItems(List<String> definedList, List<String> receivedList, String name) {
        List<String> missingItems = new ArrayList<>();
        int counter = 0;
        for (String item : definedList) {
            if (!receivedList.contains(item)) {
                missingItems.add(item);
                counter++;
            }
        }
        System.out.println("Missing " + counter + " "+name+": " + Arrays.toString(missingItems.toArray()));
    }

    private static String getStringFromUrl(String queryURL) throws IOException {
        System.out.println("\nSending 'GET' request to URL : " + queryURL);
        URL url = new URL(queryURL);
        HttpURLConnection con = (HttpURLConnection) url.openConnection();
        con.setRequestMethod("GET");
        int responseCode = con.getResponseCode();
        System.out.println("Response Code : " + responseCode);

        BufferedReader in = new BufferedReader(new InputStreamReader(con.getInputStream()));
        String inputLine;
        StringBuilder stringBuilder = new StringBuilder();
        while ((inputLine = in.readLine()) != null) {
            stringBuilder.append(inputLine);
        }
        return stringBuilder.toString();
    }

    private static List<String> readListFromFile(String filename) {
        List<String> result = new ArrayList<>();
        File file = new File(filename);
        try (BufferedReader br = new BufferedReader(new FileReader(file))) {
            String line;
            while ((line = br.readLine()) != null) {
                result.add(line);
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
        return result;
    }

    private static String separatedByCommas(List<String> list) {
        //System.out.println(Arrays.toString(list.toArray()));
        String result = "";
        String separator = "";
        for (String elem : list) {
            result += separator + elem;
            separator = ",";
        }
        return result;
    }
}
