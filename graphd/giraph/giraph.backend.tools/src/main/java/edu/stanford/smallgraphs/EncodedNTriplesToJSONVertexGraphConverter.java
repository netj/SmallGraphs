package edu.stanford.smallgraphs;

import info.aduna.io.ByteArrayUtil;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.util.List;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.GnuParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.json.JSONException;
import org.json.JSONWriter;
import org.openrdf.model.Literal;
import org.openrdf.model.Resource;
import org.openrdf.model.Statement;
import org.openrdf.model.URI;
import org.openrdf.model.Value;
import org.openrdf.rio.RDFFormat;
import org.openrdf.rio.RDFHandlerException;
import org.openrdf.rio.RDFParseException;
import org.openrdf.rio.RDFParser;
import org.openrdf.rio.Rio;
import org.openrdf.rio.helpers.RDFHandlerBase;

import com.sleepycat.je.Cursor;
import com.sleepycat.je.CursorConfig;
import com.sleepycat.je.Database;
import com.sleepycat.je.DatabaseConfig;
import com.sleepycat.je.DatabaseEntry;
import com.sleepycat.je.Environment;
import com.sleepycat.je.EnvironmentConfig;
import com.sleepycat.je.LockMode;
import com.sleepycat.je.OperationStatus;

public class EncodedNTriplesToJSONVertexGraphConverter {

	private Database edgeListByVertex;
	private Database propertyMapByVertex;

	public EncodedNTriplesToJSONVertexGraphConverter(File outputDir) {
		// initialize BerkeleyDB
		EnvironmentConfig envConfig = new EnvironmentConfig();
		envConfig.setAllowCreate(true);
		Environment myDbEnvironment = new Environment(outputDir, envConfig);
		DatabaseConfig dbConfig = new DatabaseConfig();
		dbConfig.setAllowCreate(true);
		dbConfig.setDeferredWrite(true);
		dbConfig.setSortedDuplicates(true);
		edgeListByVertex = myDbEnvironment.openDatabase(null, "vertices",
				dbConfig);
		propertyMapByVertex = myDbEnvironment.openDatabase(null, "properties",
				dbConfig);
	}

	DatabaseEntry vertexIdDBEntry = new DatabaseEntry(new byte[8]);
	DatabaseEntry edgeDBEntry = new DatabaseEntry(new byte[2 * 8]);

	protected void addEdge(URI sURI, URI pURI, URI oURI) {
		Long sId = Long.valueOf(sURI.stringValue().substring(1));
		Long pId = Long.valueOf(pURI.stringValue().substring(1));
		Long oId = Long.valueOf(oURI.stringValue().substring(1));
		// System.err.println("+ " + sId + "-" + pId + "->" + oId);
		ByteArrayUtil.putLong(sId, vertexIdDBEntry.getData(), 0);
		byte[] edgeData = edgeDBEntry.getData();
		ByteArrayUtil.putLong(pId, edgeData, 0);
		ByteArrayUtil.putLong(oId, edgeData, 8);
		edgeListByVertex.put(null, vertexIdDBEntry, edgeDBEntry);
	}

	DatabaseEntry propertyDBEntry = new DatabaseEntry();
	byte[] propertyIdBuffer = new byte[8];

	protected void addProperty(URI sURI, URI pURI, Literal oLiteral)
			throws IOException, JSONException {
		Long sId = Long.valueOf(sURI.stringValue().substring(1));
		Long pId = Long.valueOf(pURI.stringValue().substring(1));
		// System.err.println("+ " + sId + "@" + pId);
		ByteArrayUtil.putLong(sId, vertexIdDBEntry.getData(), 0);
		ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
		// write predicate Id
		ByteArrayUtil.putLong(pId, propertyIdBuffer, 0);
		byteArrayOutputStream.write(propertyIdBuffer);
		// then, the value in JSON
		byteArrayOutputStream.write(oLiteral.stringValue().getBytes());
		byteArrayOutputStream.close();
		byte[] byteArray = byteArrayOutputStream.toByteArray();
		// store it in the map
		propertyDBEntry.setData(byteArray);
		propertyMapByVertex.put(null, vertexIdDBEntry, propertyDBEntry);
	}

	private void convert(InputStream input, OutputStream output)
			throws RDFParseException, RDFHandlerException, IOException,
			JSONException {
		// parse N-Triples input and collect them in the maps
		RDFParser parser = Rio.createParser(RDFFormat.NTRIPLES);
		parser.setRDFHandler(new RDFHandlerBase() {
			@Override
			public void handleStatement(Statement st)
					throws RDFHandlerException {
				Resource s = st.getSubject();
				URI p = st.getPredicate();
				Value o = st.getObject();
				if (s instanceof URI) {
					URI sURI = (URI) s;
					if (o instanceof URI) {
						// edges
						URI oURI = (URI) o;
						addEdge(sURI, p, oURI);
					} else if (o instanceof Literal) {
						// properties
						Literal oLiteral = (Literal) o;
						try {
							addProperty(sURI, p, oLiteral);
						} catch (IOException e) {
							e.printStackTrace();
						} catch (JSONException e) {
							e.printStackTrace();
						}
					}
				}
				// TODO what else?
			}
		});
		parser.parse(input, "");
		// from the maps, output vertex-grouped graph in multiple lines of JSON
		OutputStreamWriter outputStreamWriter = new OutputStreamWriter(output);
		CursorConfig cursorConfig = new CursorConfig();
		Cursor cursor = edgeListByVertex.openCursor(null, cursorConfig);
		OperationStatus status;
		DatabaseEntry vertexEntry = new DatabaseEntry();
		DatabaseEntry edgeEntry = new DatabaseEntry();
		status = cursor.getFirst(vertexEntry, edgeEntry, LockMode.DEFAULT);
		while (status == OperationStatus.SUCCESS) {
			JSONWriter jsonWriter = new JSONWriter(outputStreamWriter);
			jsonWriter.array();
			// source vertex id
			long sId = ByteArrayUtil.getLong(vertexEntry.getData(), 0);
			jsonWriter.value(sId);
			// edge list
			jsonWriter.array();
			do {
				byte[] edgeData = edgeEntry.getData();
				long pId = ByteArrayUtil.getLong(edgeData, 0);
				long oId = ByteArrayUtil.getLong(edgeData, 8);
				// System.err.println("= " + sId + "-" + pId + "->" + oId);
				// target vertex id
				jsonWriter.value(oId);
				// edge properties
				jsonWriter.object();
				// type
				jsonWriter.key("");
				jsonWriter.value(pId);
				// TODO more edge properties
				jsonWriter.endObject();
				status = cursor.getNextDup(vertexEntry, edgeEntry,
						LockMode.DEFAULT);
			} while (status == OperationStatus.SUCCESS);
			jsonWriter.endArray();
			// node properties
			jsonWriter.object();
			// TODO
			Cursor propertiesCursor = propertyMapByVertex.openCursor(null,
					cursorConfig);
			DatabaseEntry propertyEntry = new DatabaseEntry();
			status = propertiesCursor.getSearchKey(vertexEntry, propertyEntry,
					LockMode.DEFAULT);
			while (status == OperationStatus.SUCCESS) {
				byte[] propertyIdValue = propertyEntry.getData();
				jsonWriter.key(Long.toString(ByteArrayUtil.getLong(
						propertyIdValue, 0)));
				jsonWriter.value(new String(propertyIdValue, 8,
						propertyIdValue.length - 8));
				status = propertiesCursor.getNextDup(vertexEntry,
						propertyEntry, LockMode.DEFAULT);
			}
			jsonWriter.endObject();
			jsonWriter.endArray();
			outputStreamWriter.flush();
			output.write('\n');
			status = cursor.getNextNoDup(vertexEntry, edgeEntry,
					LockMode.DEFAULT);
		}
	}

	public static void main(String[] args) {
		// command line options
		Options options = new Options();
		options.addOption("o", true, "Path to output directory");
		CommandLine parsedArgs;
		try {
			parsedArgs = new GnuParser().parse(options, args, false);
		} catch (ParseException e) {
			printUsage(options);
			System.exit(1);
			return;
		}

		// process arguments
		String outputPath = parsedArgs.getOptionValue("o", "output");
		@SuppressWarnings("unchecked")
		List<String> files = parsedArgs.getArgList();
		if (files.size() == 0) {
			printUsage(options);
			System.exit(1);
			return;
		}

		try {
			File outputDir = new File(outputPath);
			outputDir.mkdirs();
			EncodedNTriplesToJSONVertexGraphConverter graphImporter = new EncodedNTriplesToJSONVertexGraphConverter(
					outputDir);
			for (String filename : files) {
				InputStream input = filename.equals("-") ? System.in
						: new FileInputStream(filename);
				graphImporter.convert(input, System.out);
			}
		} catch (RDFParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (RDFHandlerException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (FileNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (JSONException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}

	private static void printUsage(Options options) {
		HelpFormatter formatter = new HelpFormatter();
		formatter
				.printHelp(
						"EncodedNTriplesToJSONVertexGraphConverter [OPTIONS] ENCODED_RDF_FILE...",
						options);
		System.out.println();
		System.out.println("FORMAT is one from:\n"
				+ RDFFormat.values().toString());
	}

}
