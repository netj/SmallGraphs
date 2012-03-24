package edu.stanford.smallgraphs.util;

import info.aduna.io.ByteArrayUtil;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.PipedInputStream;
import java.io.PipedOutputStream;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.GnuParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.collections.CollectionUtils;
import org.json.JSONException;
import org.json.JSONObject;
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

public class RDFGraphTransformer {

	private static final String OPTION_GRAPHDATA_PATH = "g";
	private static final String OPTION_DICTIONARY_PATH = "d";
	private static final String OPTION_IMPORT_ENCODED_NTRIPLES = "importEncodedNTriples";
	private static final String OPTION_IMPORT_UNENCODED_NTRIPLES = "importUnencodedNTriples";
	private static final String OPTION_OUTPUT_JSON_VERTEX_GRAPH = "outputJSONVertexGraph";
	private static final String OPTION_DERIVE_SCHEMA = "deriveSchema";

	private static final String DEFAULT_GRAPHDATA_PATH = "map";

	private final File graphDir;
	private Environment dbEnv;
	private Database edgeListByVertex;
	private Database propertyMapByVertex;

	private final RDFDictionaryCodec dictionaryCodec;
	private long typePredicateId;
	private long labelPredicateId;

	public RDFGraphTransformer(File graphDir, File dictDir) {
		this.graphDir = graphDir;

		// open dictionary
		dictionaryCodec = new RDFDictionaryCodec(dictDir, false);
		typePredicateId = dictionaryCodec
				.encodeOrRegister(RDFDictionaryCodec.RDF_TYPE_PREDICATE_URI);
		labelPredicateId = dictionaryCodec
				.encodeOrRegister(RDFDictionaryCodec.RDF_LABEL_PREDICATE_URI);

		// initialize BerkeleyDB
		EnvironmentConfig envConfig = new EnvironmentConfig().setAllowCreate(
				true).setLocking(true);
		dbEnv = new Environment(this.graphDir, envConfig);
		DatabaseConfig dbConfig = new DatabaseConfig().setAllowCreate(true)
				.setDeferredWrite(true).setSortedDuplicates(true);
		edgeListByVertex = dbEnv.openDatabase(null, "vertices", dbConfig);
		propertyMapByVertex = dbEnv.openDatabase(null, "properties", dbConfig);

		objectIdLookupCursor = edgeListByVertex.openCursor(null, cursorConfig);
		propertyValueLookupCursor = propertyMapByVertex.openCursor(null,
				cursorConfig);
	}

	@Override
	protected void finalize() throws Throwable {
		edgeListByVertex.close();
		propertyMapByVertex.close();
		dbEnv.close();
	}

	public RDFDictionaryCodec getDictionaryCodec() {
		return dictionaryCodec;
	}

	DatabaseEntry vertexIdDBEntry = new DatabaseEntry(new byte[8]);
	DatabaseEntry edgeDBEntry = new DatabaseEntry(new byte[2 * 8]);

	protected void addEdge(URI sURI, URI pURI, URI oURI) {
		// long encoded URIs have form of: ":1234"
		long sId = Long.valueOf(sURI.stringValue().substring(1));
		long pId = Long.valueOf(pURI.stringValue().substring(1));
		long oId = Long.valueOf(oURI.stringValue().substring(1));
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
		// long encoded URIs have form of: ":1234"
		long sId = Long.valueOf(sURI.stringValue().substring(1));
		long pId = Long.valueOf(pURI.stringValue().substring(1));
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

	public void loadNTriples(InputStream input) throws RDFParseException,
			RDFHandlerException, IOException, JSONException {
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
	}

	public void writeVertexOrientedGraphInJSON(OutputStream output)
			throws JSONException, IOException {
		// from the maps, output vertex-grouped graph in multiple lines of JSON
		OutputStreamWriter outputStreamWriter = new OutputStreamWriter(output);
		CursorConfig cursorConfig = new CursorConfig();
		Cursor edgeCursor = edgeListByVertex.openCursor(null, cursorConfig);
		Cursor propertiesCursor = propertyMapByVertex.openCursor(null,
				cursorConfig);
		DatabaseEntry vertexEntry = new DatabaseEntry();
		DatabaseEntry edgeEntry = new DatabaseEntry();
		DatabaseEntry propertyEntry = new DatabaseEntry();
		OperationStatus status = edgeCursor.getFirst(vertexEntry, edgeEntry,
				LockMode.DEFAULT);
		while (status == OperationStatus.SUCCESS) {
			JSONWriter jsonWriter = new JSONWriter(outputStreamWriter);
			jsonWriter.array();
			{
				// source vertex id
				long sId = ByteArrayUtil.getLong(vertexEntry.getData(), 0);
				jsonWriter.value(sId);
				// edge list
				Long vertexTypeId = writeVertexEdgesInJSON(jsonWriter,
						edgeCursor, propertiesCursor, vertexEntry, edgeEntry,
						propertyEntry);
				// node properties
				writeVertexPropertiesInJSON(jsonWriter, propertiesCursor,
						vertexEntry, propertyEntry, vertexTypeId);
			}
			jsonWriter.endArray();
			outputStreamWriter.flush();
			output.write('\n');
			status = edgeCursor.getNextNoDup(vertexEntry, edgeEntry,
					LockMode.DEFAULT);
		}
		edgeCursor.close();
		propertiesCursor.close();
	}

	private Long writeVertexEdgesInJSON(JSONWriter jsonWriter,
			Cursor edgeCursor, Cursor propertiesCursor,
			DatabaseEntry vertexEntry, DatabaseEntry edgeEntry,
			DatabaseEntry propertyEntry) throws JSONException {
		OperationStatus status;
		jsonWriter.array();
		Long vertexTypeId = null;
		do {
			byte[] edgeData = edgeEntry.getData();
			long pId = ByteArrayUtil.getLong(edgeData, 0);
			long oId = ByteArrayUtil.getLong(edgeData, 8);
			if (vertexTypeId == null && pId == typePredicateId) {
				// keep the oId as vertex type
				vertexTypeId = oId;
				// skip the type edge since it'll be done as property
			} else {
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
			}
			status = edgeCursor.getNextDup(vertexEntry, edgeEntry,
					LockMode.DEFAULT);
		} while (status == OperationStatus.SUCCESS);
		jsonWriter.endArray();
		return vertexTypeId;
	}

	private void writeVertexPropertiesInJSON(JSONWriter jsonWriter,
			Cursor propertiesCursor, DatabaseEntry vertexEntry,
			DatabaseEntry propertyEntry, Long vertexTypeId)
			throws JSONException {
		jsonWriter.object();
		{
			if (vertexTypeId != null) {
				// vertex type
				jsonWriter.key("");
				jsonWriter.value(vertexTypeId.longValue());
			}
			OperationStatus status = propertiesCursor.getSearchKey(vertexEntry,
					propertyEntry, LockMode.DEFAULT);
			Long prevPropertyId = null;
			String prevPropertyValue = null;
			boolean hasMultipleProperties = false;
			while (status == OperationStatus.SUCCESS) {
				byte[] propertyIdValue = propertyEntry.getData();
				long propertyId = ByteArrayUtil.getLong(propertyIdValue, 0);
				if (prevPropertyId == null || propertyId != prevPropertyId) {
					// for a new property id, write the end of the array or
					// previous value and start a new key
					if (prevPropertyValue != null)
						jsonWriter.value(prevPropertyValue);
					if (hasMultipleProperties) {
						jsonWriter.endArray();
						hasMultipleProperties = false;
					}
					jsonWriter.key(Long.toString(propertyId));
					prevPropertyId = propertyId;
				} else {
					// put in an array if node has multiple values for the same
					// property
					if (!hasMultipleProperties) {
						jsonWriter.array();
						hasMultipleProperties = true;
					}
					jsonWriter.value(prevPropertyValue);
				}
				prevPropertyValue = new String(propertyIdValue, 8,
						propertyIdValue.length - 8);
				status = propertiesCursor.getNextDup(vertexEntry,
						propertyEntry, LockMode.DEFAULT);
			}
			if (prevPropertyValue != null) {
				// just make sure we write the last value and close the array
				jsonWriter.value(prevPropertyValue);
				if (hasMultipleProperties)
					jsonWriter.endArray();
			}
		}
		jsonWriter.endObject();
	}

	CursorConfig cursorConfig = new CursorConfig();

	public void deriveSchema(OutputStream output) throws JSONException,
			IOException {
		// from the maps, scan each vertex and its edges, properties to
		// construct a schema
		Set<Long> vertexTypes = new HashSet<Long>();
		Map<Long, Set<Long>> domainByEdge = new HashMap<Long, Set<Long>>();
		Map<Long, Set<Long>> rangeByEdge = new HashMap<Long, Set<Long>>();
		Map<Long, Set<Long>> propertiesByVertex = new HashMap<Long, Set<Long>>();
		Map<Long, String> dataTypeByProperty = new HashMap<Long, String>();
		Cursor edgeCursor = edgeListByVertex.openCursor(null, cursorConfig);
		Cursor propertiesCursor = propertyMapByVertex.openCursor(null,
				cursorConfig);
		DatabaseEntry vertexEntry = new DatabaseEntry();
		DatabaseEntry edgeEntry = new DatabaseEntry();
		DatabaseEntry propertyEntry = new DatabaseEntry();
		OperationStatus status = edgeCursor.getFirst(vertexEntry, edgeEntry,
				LockMode.DEFAULT);
		// for each vertex
		while (status == OperationStatus.SUCCESS) {
			long sId = ByteArrayUtil.getLong(vertexEntry.getData(), 0);
			Long sTypeId = lookupType(sId);
			if (sTypeId != null) {
				vertexTypes.add(sTypeId);
				// for each of its edge
				do {
					byte[] edgeData = edgeEntry.getData();
					long pId = ByteArrayUtil.getLong(edgeData, 0);
					long oId = ByteArrayUtil.getLong(edgeData, 8);
					Long oTypeId = lookupType(oId);
					if (pId != typePredicateId && oTypeId != null) {
						// construct the domain and range of each edge
						getSet(domainByEdge, pId).add(sTypeId);
						getSet(rangeByEdge, pId).add(oTypeId);
					}
					status = edgeCursor.getNextDup(vertexEntry, edgeEntry,
							LockMode.DEFAULT);
				} while (status == OperationStatus.SUCCESS);
				// then, for each of its properties
				status = propertiesCursor.getSearchKey(vertexEntry,
						propertyEntry, LockMode.DEFAULT);
				while (status == OperationStatus.SUCCESS) {
					byte[] propertyIdValue = propertyEntry.getData();
					long propertyId = ByteArrayUtil.getLong(propertyIdValue, 0);
					getSet(propertiesByVertex, sTypeId).add(propertyId);
					// guess type of value
					if (!dataTypeByProperty.containsKey(propertyId)) {
						String propertyValue = new String(propertyIdValue, 8,
								propertyIdValue.length - 8);
						Object value = JSONObject.stringToValue(propertyValue);
						if (value instanceof String) {
							dataTypeByProperty.put(propertyId, "xsd:string");
						} else if (value instanceof Long
								|| value instanceof Integer) {
							dataTypeByProperty.put(propertyId, "xsd:decimal");
						} else if (value instanceof Double) {
							dataTypeByProperty.put(propertyId, "xsd:double");
						} else if (value instanceof Float) {
							dataTypeByProperty.put(propertyId, "xsd:float");
						} else {
							dataTypeByProperty.put(propertyId, "xsd:anyType");
						}
					}
					status = propertiesCursor.getNextDup(vertexEntry,
							propertyEntry, LockMode.DEFAULT);
				}
			}
			status = edgeCursor.getNextNoDup(vertexEntry, edgeEntry,
					LockMode.DEFAULT);
		}

		// now, output schema which contains:
		// - maps with node/edge type/uri <-> id
		// - compact domain/range representation
		OutputStreamWriter outputStreamWriter = new OutputStreamWriter(output);
		JSONWriter jsonWriter = new JSONWriter(outputStreamWriter);
		jsonWriter.object();
		jsonWriter.key("nodeTypes");
		{
			jsonWriter.object();
			for (Long vType : vertexTypes) {
				jsonWriter.key(vType.toString());
				{
					jsonWriter.object();
					jsonWriter.key("name");
					jsonWriter.value(getTypeName(vType));
					jsonWriter.key("properties");
					writeSetAsJSONArray(jsonWriter,
							propertiesByVertex.get(vType));
					jsonWriter.key("labelProperty");
					jsonWriter.value(labelPredicateId);
					jsonWriter.endObject();
				}
			}
			jsonWriter.endObject();
		}
		jsonWriter.key("edgeTypes");
		{
			jsonWriter.object();
			for (Long eType : domainByEdge.keySet()) {
				jsonWriter.key(eType.toString());
				{
					jsonWriter.object();
					jsonWriter.key("name");
					jsonWriter.value(getTypeName(eType));
					jsonWriter.key("domain");
					writeSetAsJSONArray(jsonWriter, domainByEdge.get(eType));
					jsonWriter.key("range");
					writeSetAsJSONArray(jsonWriter, rangeByEdge.get(eType));
					jsonWriter.endObject();
				}
			}
			jsonWriter.endObject();
		}
		jsonWriter.key("properties");
		{
			jsonWriter.object();
			for (Long propertyId : dataTypeByProperty.keySet()) {
				jsonWriter.key(propertyId.toString());
				{
					jsonWriter.object();
					jsonWriter.key("name");
					jsonWriter.value(getTypeName(propertyId));
					jsonWriter.key("dataType");
					jsonWriter.value(dataTypeByProperty.get(propertyId));
					jsonWriter.endObject();
				}
			}
			jsonWriter.endObject();
		}
		jsonWriter.key("uris");
		{
			jsonWriter.object();
			@SuppressWarnings("unchecked")
			Collection<Long> ids = CollectionUtils.union(vertexTypes,
					CollectionUtils.union(domainByEdge.keySet(),
							dataTypeByProperty.keySet()));
			for (Long id : ids) {
				jsonWriter.key(id.toString());
				jsonWriter.value(dictionaryCodec.decode(id));
			}
			jsonWriter.endObject();
		}
		jsonWriter.endObject();
		outputStreamWriter.flush();
	}

	private String getTypeName(Long typeId) {
		String label = lookupFirstPropertyValue(typeId, labelPredicateId);
		if (label != null)
			return label;
		else {
			String uri = dictionaryCodec.decode(typeId);
			return uri.replaceFirst(".*[/#]", "");
		}
	}

	private void writeSetAsJSONArray(JSONWriter jsonWriter, Set<Long> set)
			throws JSONException {
		jsonWriter.array();
		for (Long id : set)
			jsonWriter.value(id);
		jsonWriter.endArray();
	}

	private Set<Long> getSet(Map<Long, Set<Long>> domainByEdge, long pId) {
		Set<Long> domain = domainByEdge.get(pId);
		if (domain == null) {
			domain = new HashSet<Long>();
			domainByEdge.put(pId, domain);
		}
		return domain;
	}

	private Cursor objectIdLookupCursor;
	private DatabaseEntry objectIdLookupVertexEntry = new DatabaseEntry(
			new byte[8]);
	private DatabaseEntry objectIdLookupEdgeEntry = new DatabaseEntry();

	private Long lookupType(long sId) {
		return lookupFirstObjectId(sId, typePredicateId);
	}

	private Long lookupFirstObjectId(long subjectId, long predicateId) {
		ByteArrayUtil
				.putLong(subjectId, objectIdLookupVertexEntry.getData(), 0);
		OperationStatus status = objectIdLookupCursor.getSearchKey(
				objectIdLookupVertexEntry, objectIdLookupEdgeEntry,
				LockMode.DEFAULT);
		while (status == OperationStatus.SUCCESS) {
			byte[] edgeData = objectIdLookupEdgeEntry.getData();
			long pId = ByteArrayUtil.getLong(edgeData, 0);
			if (pId == predicateId)
				return ByteArrayUtil.getLong(edgeData, 8);
			status = objectIdLookupCursor.getNextDup(objectIdLookupVertexEntry,
					objectIdLookupEdgeEntry, LockMode.DEFAULT);
		}
		return null;
	}

	private Cursor propertyValueLookupCursor;
	private DatabaseEntry propertyValueLookupVertexEntry = new DatabaseEntry(
			new byte[8]);
	DatabaseEntry propertyValueLookupValueEntry = new DatabaseEntry();

	private String lookupFirstPropertyValue(long subjectId, long predicateId) {
		ByteArrayUtil.putLong(subjectId,
				propertyValueLookupVertexEntry.getData(), 0);
		OperationStatus status = propertyValueLookupCursor.getSearchKey(
				propertyValueLookupVertexEntry, propertyValueLookupValueEntry,
				LockMode.DEFAULT);
		while (status == OperationStatus.SUCCESS) {
			byte[] propertyValueData = propertyValueLookupValueEntry.getData();
			long pId = ByteArrayUtil.getLong(propertyValueData, 0);
			if (pId == predicateId)
				return new String(propertyValueData, 8,
						propertyValueData.length - 8);
			status = propertyValueLookupCursor.getNextDup(
					propertyValueLookupVertexEntry,
					propertyValueLookupValueEntry, LockMode.DEFAULT);
		}
		return null;
	}

	private static int exitCode;
	private static Exception exc;

	public static void main(String[] args) {
		// command line options
		Options options = new Options();
		options.addOption(OPTION_DICTIONARY_PATH, true,
				"Path to the dictionary for encoding the graph (defaults to ./"
						+ RDFDictionaryCodec.DEFAULT_DICTIONARY_PATH + "/)");
		options.addOption(OPTION_GRAPHDATA_PATH, true,
				"Path to working directory for manipulating the graph (defaults to ./"
						+ DEFAULT_GRAPHDATA_PATH + "/)");
		options.addOption(OPTION_IMPORT_UNENCODED_NTRIPLES, true,
				"Load decoded N-Triples in given file");
		options.addOption(OPTION_IMPORT_ENCODED_NTRIPLES, true,
				"Load encoded N-Triples in given file by encoding them");
		options.addOption(OPTION_OUTPUT_JSON_VERTEX_GRAPH, true,
				"Output Giraph JSON graph to given directory");
		options.addOption(OPTION_DERIVE_SCHEMA, true,
				"Derive encoded schema to given file");
		CommandLine parsedArgs;
		try {
			parsedArgs = new GnuParser().parse(options, args, false);
		} catch (ParseException e) {
			printUsage(options);
			System.exit(1);
			return;
		}

		// process arguments
		String dictDirPath = parsedArgs.getOptionValue(OPTION_DICTIONARY_PATH,
				RDFDictionaryCodec.DEFAULT_DICTIONARY_PATH);
		String workDirPath = parsedArgs.getOptionValue(OPTION_GRAPHDATA_PATH,
				DEFAULT_GRAPHDATA_PATH);
		String inputUnencodedNTriplesPath = parsedArgs
				.getOptionValue(OPTION_IMPORT_UNENCODED_NTRIPLES);
		String inputEncodedNTriplesPath = parsedArgs
				.getOptionValue(OPTION_IMPORT_ENCODED_NTRIPLES);
		String outputDirPath = parsedArgs
				.getOptionValue(OPTION_OUTPUT_JSON_VERTEX_GRAPH);
		String schemaPath = parsedArgs.getOptionValue(OPTION_DERIVE_SCHEMA);
		String[] optionalArgs = parsedArgs.getArgs();
		if (inputEncodedNTriplesPath == null && outputDirPath == null
				&& schemaPath == null) {
			printUsage(options);
			System.exit(1);
			return;
		}

		try {
			File workDir = new File(workDirPath);
			workDir.mkdirs();
			File dictDir = new File(dictDirPath);
			dictDir.mkdirs();
			final RDFGraphTransformer graphTransformer = new RDFGraphTransformer(
					workDir, dictDir);
			if (inputUnencodedNTriplesPath != null) {
				// dictionary encode given n-triples and load it
				System.err.println("reading raw N-Triples from: "
						+ inputUnencodedNTriplesPath);
				final InputStream input = inputUnencodedNTriplesPath
						.equals("-") ? System.in : new FileInputStream(
						inputUnencodedNTriplesPath);
				final PipedOutputStream pipedOutput = new PipedOutputStream();
				// prepare the dictionary encoding thread
				Thread encodeThread = new Thread(new Runnable() {
					public void run() {
						try {
							graphTransformer
									.getDictionaryCodec()
									.reopen(false)
									.encode(input, RDFFormat.NTRIPLES, "",
											pipedOutput, RDFFormat.NTRIPLES);
							pipedOutput.close();
						} catch (Exception e) {
							exc = e;
						}
					}
				});
				// and another thread to load the encoded ntriples
				Thread loadThread = new Thread(new Runnable() {
					public void run() {
						try {
							PipedInputStream pipedInput = new PipedInputStream(
									pipedOutput);
							graphTransformer.loadNTriples(pipedInput);
						} catch (Exception e) {
							exc = e;
						}
					}
				});
				loadThread.start();
				encodeThread.start();
				loadThread.join();
				encodeThread.join();
				if (exc != null)
					throw exc;
			} else if (inputEncodedNTriplesPath != null) {
				// load given encoded n-triples
				System.err.println("reading encoded N-Triples from: "
						+ inputEncodedNTriplesPath);
				String filename = inputEncodedNTriplesPath;
				InputStream input = filename.equals("-") ? System.in
						: new FileInputStream(filename);
				graphTransformer.loadNTriples(input);
			}
			if (outputDirPath != null) {
				// output JSON graph for Giraph
				System.err
						.println("writing graph as a JSON line for each vertex: "
								+ outputDirPath);
				File outputDir = new File(outputDirPath);
				outputDir.mkdirs();
				// TODO spread into multiple parts
				graphTransformer
						.writeVertexOrientedGraphInJSON(new FileOutputStream(
								new File(outputDir, "part-m-00001")));
			}
			if (schemaPath != null) {
				// derive and output schema
				System.err.println("deriving graph schema to: " + schemaPath);
				OutputStream output = schemaPath.equals("-") ? System.out
						: new FileOutputStream(schemaPath);
				graphTransformer.deriveSchema(output);
			}
		} catch (Exception e) {
			e.printStackTrace();
			exitCode = 2;
		}
		System.exit(exitCode);
	}

	private static void printUsage(Options options) {
		HelpFormatter formatter = new HelpFormatter();
		formatter.printHelp(RDFGraphTransformer.class.getName()
				+ " [OPTIONS] ENCODED_RDF_FILE...", options);
		System.out.println();
		System.out
				.println("Use - for file name to read from STDIN or write to STDOUT.");
		// System.out.println("FORMAT is one from:\n"
		// + RDFFormat.values().toString());
	}

}
