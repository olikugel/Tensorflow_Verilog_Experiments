/* Copyright 2015 Google Inc. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

// A minimal but useful C++ example showing how to load an Imagenet-style object
// recognition TensorFlow model, prepare input images for it, run them through
// the graph, and interpret the results.
//
// It's designed to have as few dependencies and be as clear as possible, so
// it's more verbose than it could be in production code. In particular, using
// auto for the types of a lot of the returned values from TensorFlow calls can
// remove a lot of boilerplate, but I find the explicit types useful in sample
// code to make it simple to look up the classes involved.
//
// To use it, compile and then run in a working directory with the
// learning/brain/tutorials/label_image/data/ folder below it, and you should
// see the top five labels for the example Lena image output. You can then
// customize it to use your own models or images by changing the file names at
// the top of the main() function.
//
// The googlenet_graph.pb file included by default is created from Inception.

#include <fstream>
#include <vector>
#include <string>
#include <iostream>

#include "tensorflow/cc/ops/const_op.h"
#include "tensorflow/cc/ops/image_ops.h"
#include "tensorflow/cc/ops/standard_ops.h"
#include "tensorflow/core/framework/graph.pb.h"
#include "tensorflow/core/framework/tensor.h"
#include "tensorflow/core/graph/default_device.h"
#include "tensorflow/core/graph/graph_def_builder.h"
#include "tensorflow/core/lib/core/errors.h"
#include "tensorflow/core/lib/core/stringpiece.h"
#include "tensorflow/core/lib/core/threadpool.h"
#include "tensorflow/core/lib/io/path.h"
#include "tensorflow/core/lib/strings/stringprintf.h"
#include "tensorflow/core/platform/init_main.h"
#include "tensorflow/core/platform/logging.h"
#include "tensorflow/core/platform/types.h"
#include "tensorflow/core/public/session.h"
#include "tensorflow/core/util/command_line_flags.h"
#include "tensorflow/core/framework/tensor.pb.h"
#include "tensorflow/core/framework/tensor_shape.pb.h"
#include "tensorflow/core/framework/tensor_shape.h"


// These are all common classes it's handy to reference with no namespace.
using tensorflow::Flag;
using tensorflow::Tensor;
using tensorflow::Status;
using tensorflow::string;
using tensorflow::int32;
using tensorflow::TensorProto;
using tensorflow::TensorShape;
using namespace std;

typedef std::vector<std::pair<string, Tensor>> NamedTensorList;

// Takes a file name, and loads a list of labels from it, one per line, and
// returns a vector of the strings. It pads with empty strings so the length
// of the result is a multiple of 16, because our model expects that.
Status ReadLabelsFile(string file_name, std::vector<string>* result,
                      size_t* found_label_count) {
  std::ifstream file(file_name);
  if (!file) {
    return tensorflow::errors::NotFound("Labels file ", file_name,
                                        " not found.");
  }
  result->clear();
  string line;
  while (std::getline(file, line)) {
    result->push_back(line);
  }
  *found_label_count = result->size();
  const int padding = 16;
  while (result->size() % padding) {
    result->emplace_back();
  }
  return Status::OK();
}


// Given an image file name, read in the data, try to decode it as an image,
// resize it to the requested size, and then scale the values as desired.
Status ReadTensorFromImageFile(string file_name, const int input_height,
                               const int input_width, const float input_mean,
                               const float input_std,
                               std::vector<Tensor>* out_tensors) {
  auto root = tensorflow::Scope::NewRootScope();
  using namespace ::tensorflow::ops;  // NOLINT(build/namespaces)

  string input_name = "file_reader";
  string output_name = "normalized";
  auto file_reader = tensorflow::ops::ReadFile(root.WithOpName(input_name),
                                               file_name);
  // Now try to figure out what kind of file it is and decode it.
  const int wanted_channels = 3;
  tensorflow::Output image_reader;
  if (tensorflow::StringPiece(file_name).ends_with(".png")) {
    image_reader = DecodePng(root.WithOpName("png_reader"), file_reader,
                             DecodePng::Channels(wanted_channels));
  } else if (tensorflow::StringPiece(file_name).ends_with(".gif")) {
    image_reader = DecodeGif(root.WithOpName("gif_reader"), file_reader);
  } else {
    // Assume if it's neither a PNG nor a GIF then it must be a JPEG.
    image_reader = DecodeJpeg(root.WithOpName("jpeg_reader"), file_reader,
                              DecodeJpeg::Channels(wanted_channels));
  }
  // Now cast the image data to float so we can do normal math on it.
  auto float_caster =
      Cast(root.WithOpName("float_caster"), image_reader, tensorflow::DT_FLOAT);
  // The convention for image ops in TensorFlow is that all images are expected
  // to be in batches, so that they're four-dimensional arrays with indices of
  // [batch, height, width, channel]. Because we only have a single image, we
  // have to add a batch dimension of 1 to the start with ExpandDims().
  auto dims_expander = ExpandDims(root, float_caster, 0);
  // Bilinearly resize the image to fit the required dimensions.
  auto resized = ResizeBilinear(
      root, dims_expander,
      Const(root.WithOpName("size"), {input_height, input_width}));
  // Subtract the mean and divide by the scale.
  Div(root.WithOpName(output_name), Sub(root, resized, {input_mean}),
      {input_std});

  // This runs the GraphDef network definition that we've just constructed, and
  // returns the results in the output tensor.
  tensorflow::GraphDef graph;
  TF_RETURN_IF_ERROR(root.ToGraphDef(&graph));

  std::unique_ptr<tensorflow::Session> session(
      tensorflow::NewSession(tensorflow::SessionOptions()));
  TF_RETURN_IF_ERROR(session->Create(graph));
  TF_RETURN_IF_ERROR(session->Run({}, {output_name}, {}, out_tensors));
  return Status::OK();
}


// Reads a model graph definition from disk, and creates a session object you
// can use to run it.
Status LoadGraph(string graph_file_name,
                 std::unique_ptr<tensorflow::Session>* session) {
  tensorflow::GraphDef graph_def;
  Status load_graph_status =
      ReadBinaryProto(tensorflow::Env::Default(), graph_file_name, &graph_def);
  if (!load_graph_status.ok()) {
    return tensorflow::errors::NotFound("Failed to load compute graph at '",
                                        graph_file_name, "'");
  }
  session->reset(tensorflow::NewSession(tensorflow::SessionOptions()));
  Status session_create_status = (*session)->Create(graph_def);
  if (!session_create_status.ok()) {
    return session_create_status;
  }
  return Status::OK();
}


// Analyzes the output of the Inception graph to retrieve the highest scores and
// their positions in the tensor, which correspond to categories.
Status GetTopLabels(const std::vector<Tensor>& outputs, int how_many_labels,
                    Tensor* indices, Tensor* scores) {
  auto root = tensorflow::Scope::NewRootScope();
  using namespace ::tensorflow::ops;  // NOLINT(build/namespaces)

  string output_name = "top_k";
  TopK(root.WithOpName(output_name), outputs[0], how_many_labels);
  // This runs the GraphDef network definition that we've just constructed, and
  // returns the results in the output tensors.
  tensorflow::GraphDef graph;
  TF_RETURN_IF_ERROR(root.ToGraphDef(&graph));

  std::unique_ptr<tensorflow::Session> session(
      tensorflow::NewSession(tensorflow::SessionOptions()));
  TF_RETURN_IF_ERROR(session->Create(graph));
  // The TopK node returns two outputs, the scores and their original indices,
  // so we have to append :0 and :1 to specify them both.
  std::vector<Tensor> out_tensors;
  TF_RETURN_IF_ERROR(session->Run({}, {output_name + ":0", output_name + ":1"},
                                  {}, &out_tensors));
  *scores = out_tensors[0];
  *indices = out_tensors[1];
  return Status::OK();
}


// Given the output of a model run, and the name of a file containing the labels
// this prints out the top five highest-scoring values.
Status PrintTopLabels(const std::vector<Tensor>& outputs,
                      string labels_file_name) {
  std::vector<string> labels;
  size_t label_count;
  Status read_labels_status =
      ReadLabelsFile(labels_file_name, &labels, &label_count);
  if (!read_labels_status.ok()) {
    LOG(ERROR) << read_labels_status;
    return read_labels_status;
  }
  const int how_many_labels = std::min(5, static_cast<int>(label_count));
  Tensor indices;
  Tensor scores;
  TF_RETURN_IF_ERROR(GetTopLabels(outputs, how_many_labels, &indices, &scores));
  tensorflow::TTypes<float>::Flat scores_flat = scores.flat<float>();
  tensorflow::TTypes<int32>::Flat indices_flat = indices.flat<int32>();
  for (int pos = 0; pos < how_many_labels; ++pos) {
    const int label_index = indices_flat(pos);
    float score = scores_flat(pos);
    LOG(INFO) << labels[label_index] << " (" << label_index << "): " << score; // prints classifications!
  }
  return Status::OK();
}

// This is a testing function that returns whether the top label index is the
// one that's expected.
Status CheckTopLabel(const std::vector<Tensor>& outputs, int expected,
                     bool* is_expected) {
  *is_expected = false;
  Tensor indices;
  Tensor scores;
  const int how_many_labels = 1;
  TF_RETURN_IF_ERROR(GetTopLabels(outputs, how_many_labels, &indices, &scores));
  tensorflow::TTypes<int32>::Flat indices_flat = indices.flat<int32>();
  if (indices_flat(0) != expected) {
    LOG(ERROR) << "Expected label #" << expected << " but got #"
               << indices_flat(0);
    *is_expected = false;
  } else {
    *is_expected = true;
  }
  return Status::OK();
}


Tensor readImage(string filename) {
    string imageData;

    std::ifstream file(filename);
    file.seekg(0, std::ios::end);
    imageData.resize(file.tellg());
    file.seekg(0, std::ios::beg);
    file.read(&imageData[0], imageData.size());

    TensorProto proto;
    proto.set_dtype(tensorflow::DT_STRING);
    TensorShape({}).AsProto(proto.mutable_tensor_shape());
    proto.add_string_val(imageData); //s.data(), s.size()

    //return imageData;
    //Tensor imgTensor;
    //imgTensor.f
    Tensor result;
    if(result.FromProto(proto)); //DIRTY HACK: suppresses warning about not checking the return value
    return result;
}


// Extracts the inputs from the vecotr (making it an empty vector), and merges it with the names supplied.
NamedTensorList generateInputs(std::vector<string> inputNames, const std::vector<Tensor>& inputs) {
    NamedTensorList list;
    list.reserve(inputs.size());
    std::vector<string>::reverse_iterator name = inputNames.rbegin();

    for(std::vector<Tensor>::const_reverse_iterator it=inputs.rbegin(); it != inputs.rend(); it++) {
        list.emplace_back(std::pair<string, Tensor>(*name, *it));
        name++;
    }

    return list;
}

Status computeSegment(
    std::unique_ptr<tensorflow::Session>* session,
    const NamedTensorList& inputs,
    const std::vector<string>& output_names,
    const std::vector<string>& target_nodes,
    std::vector<Tensor>* outputs
) {
    return (*session)->Run(inputs, output_names, target_nodes, outputs);
//    TF_RETURN_IF_ERROR((*session)->Run(inputs, output_names, target_nodes, outputs));
//    return Status::OK();
}


typedef std::vector<Tensor> TensorVector;
typedef std::vector<TensorVector> TensorVectorVector;

TensorVector concatTensorVectors(TensorVectorVector vectorOfVectors)
{
  TensorVector combinedVectors;

  for (unsigned int i = 0; i < vectorOfVectors.size(); i++) {
    combinedVectors.insert(combinedVectors.end(), vectorOfVectors.at(i).begin(), vectorOfVectors.at(i).end());
  }

  return combinedVectors;
} // concatTensorVectors()



std::string bin2hex(const std::string& input)
{
    std::string HEX_TENSOR_DATA = "";
    const char hex[] = "0123456789ABCDEF";
    // int pixSepCount = 0;

    cout << "• Hexadigit Count:\t" << input.size() << endl;
    cout << "• Byte Count:\t\t" << input.size() / 2 << endl;

    for(auto sc : input)
    {
        unsigned char c = static_cast<unsigned char>(sc);
        HEX_TENSOR_DATA += hex[c >> 4];
        HEX_TENSOR_DATA += hex[c & 0xf];
        HEX_TENSOR_DATA += "\n";
        // HEX_TENSOR_DATA += " ";
        // pixSepCount++;
        // if (pixSepCount == 3) {
        //   HEX_TENSOR_DATA += "\n";
        //   pixSepCount = 0;
        // }
    } // for

    return HEX_TENSOR_DATA;
} // bin2hex()



std::vector<Tensor> getHardwareResults(std::vector<string> string_flags,
                                       std::vector<int> int_flags,
                                       std::string hardware_results_file,
                                       std::vector<Tensor> outputs)
{
    string from_node    = string_flags.at(5);
    string to_node      = string_flags.at(6);

    cout << "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" << endl;
    cout << "• PROCESSED THROUGH HARDWARE MODULE" << endl;
    cout << "• From-To:\t\t\t" << from_node << " -----> " << to_node << endl;
    cout << "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" << endl;
    cout << endl;

    return outputs;
} // getHardwareResults()



std::vector<Tensor> runPartOfGraph(std::vector<string> string_flags,
                                   std::vector<int> int_flags,
                                   std::string output_file,
                                   std::vector<Tensor> outputs)
{
  string image        = string_flags.at(0);
  string graph        = string_flags.at(1);
  string labels       = string_flags.at(2);
  int32 input_width   = int_flags.at(0);
  int32 input_height  = int_flags.at(1);
  int32 input_mean    = int_flags.at(2);
  int32 input_std     = int_flags.at(3);
  string input_layer  = string_flags.at(3);
  string output_layer = string_flags.at(4);
  string from_node    = string_flags.at(5);
  string to_node      = string_flags.at(6);
  string root_dir     = string_flags.at(7);

  // First we load and initialize the model.
  std::unique_ptr<tensorflow::Session> session;
  string graph_path = tensorflow::io::JoinPath(root_dir, graph);
  Status load_graph_status = LoadGraph(graph_path, &session);
  if (!load_graph_status.ok()) {
    LOG(ERROR) << load_graph_status;
    // return nullptr;
  }

  // Get the image from disk as a float array of numbers, resized and normalized
  // to the specifications the main graph expects.
  std::vector<Tensor> resized_tensors;
  string image_path = tensorflow::io::JoinPath(root_dir, image);
  Status read_tensor_status =
      ReadTensorFromImageFile(image_path, input_height, input_width, input_mean,
                              input_std, &resized_tensors);
  // cout << "• Image Tensor Data:\n" << bin2hex(resized_tensors.data()[0].tensor_data().ToString()) << endl;
  if (!read_tensor_status.ok()) {
    LOG(ERROR) << read_tensor_status;
    // return nullptr;
  }

  // Actually run the image through the model.
  NamedTensorList inputs;
  std::vector<string> graphNodes = {from_node, to_node};

  typedef std::vector<string>       stringvector;
  typedef std::vector<stringvector> stringvectorvector;
  const stringvectorvector cuts = {{graphNodes[0]},{graphNodes[1]}};

  for(stringvectorvector::const_iterator it=cuts.begin(); it != cuts.end()-1; ++it) {
      inputs = generateInputs(*it, outputs);
      outputs.clear();
      computeSegment(&session, inputs, it[1], {}, &outputs); // outputs are the results we need to format to match the hardware
  }

  // THIS IS HOW YOU EXTRACT BINARY DATA FROM A TENSOR: tensor.data()[0].tensor_data().ToString()

  string OUTPUT_TENSOR_DATA;
  OUTPUT_TENSOR_DATA = bin2hex(outputs.data()[0].tensor_data().ToString());

  ofstream tensorDataFile;
  tensorDataFile.open (output_file);
  tensorDataFile << OUTPUT_TENSOR_DATA; // export tensor data to file
  tensorDataFile.close();

  cout << endl;
  cout << "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" << endl;
  cout << "• Written data from output tensor to file " << "'" << output_file << "'" << endl;
  cout << "• Output Tensor Debug String:\n  " << outputs.data()[0].DebugString() << endl;
  cout << "• Size of Output Tensor:\t" << outputs.data()[0].NumElements() << endl;
  cout << "• Dims of Output Tensor:\t" << outputs.data()[0].dims() << endl;
  cout << "• From-To:\t\t\t" << graphNodes[0] << " -----> " << graphNodes[1] << endl;
  cout << "• Graph:\n  " << graph << endl;
  cout << "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" << endl;
  cout << endl;

  return outputs;

} // runPartOfGraph()



int main(int argc, char* argv[]) {
  // These are the command-line flags the program can understand.
  // They define where the graph and input data is located, and what kind of
  // input the model expects. If you train your own model, or use something
  // other than GoogLeNet you'll need to update these.
  const string GRAPH_FILE_ORI = "/Users/oliverkugel/Git/Uniproject/Graphs/tensorflow_inception_graph.pb";
  const string GRAPH_FILE_QUA = "/Users/oliverkugel/Git/Uniproject/Graphs/quantized_graph.pb";
  const string GRAPH_FILE_RED = "/Users/oliverkugel/Git/Uniproject/Graphs/reduced_graph.pb";
  const string GRAPH_FILE_RTQ = "/Users/oliverkugel/Git/Uniproject/Graphs/reduced_then_quantized_graph.pb";
  const string GRAPH_FILE_QTR = "/Users/oliverkugel/Git/Uniproject/Graphs/quantized_then_reduced_graph.pb";
  const string IMAGE_FILE     = "tensorflow/examples/graph_segment/data/cropped_panda.jpg";
  const string LABELS_FILE    = "tensorflow/examples/graph_segment/data/imagenet_comp_graph_label_strings.txt";

  string image  = IMAGE_FILE;
  string graph  = GRAPH_FILE_ORI;
  string labels = LABELS_FILE;

  int32 input_width  = 299;
  int32 input_height = 299;
  int32 input_mean   = 128;
  int32 input_std    = 128;

  string input_layer  = "Mul";
  string output_layer = "softmax";
  string from_node    = "Mul";
  string to_node      = "softmax";

  bool self_test  = false;
  string root_dir = "";
  int32 numberOfChannels = 3;

  std::vector<Flag> flag_list = {
      Flag("image", &image, "image to be processed"),
      Flag("graph", &graph, "graph to be executed"),
      Flag("labels", &labels, "name of file containing labels"),
      Flag("input_width", &input_width, "resize image to this width in pixels"),
      Flag("input_height", &input_height,
           "resize image to this height in pixels"),
      Flag("input_mean", &input_mean, "scale pixel values to this mean"),
      Flag("input_std", &input_std, "scale pixel values to this std deviation"),
      Flag("input_layer", &input_layer, "name of input layer"),
      Flag("output_layer", &output_layer, "name of output layer"),
      Flag("self_test", &self_test, "run a self test"),
      Flag("root_dir", &root_dir,
           "interpret image and graph file names relative to this directory"),
      Flag("from_node", &from_node, "running from this node"),
      Flag("to_node", &to_node, "running to this node")
  };

  string usage = tensorflow::Flags::Usage(argv[0], flag_list);

  const bool parse_result = tensorflow::Flags::Parse(&argc, argv, flag_list);
  if (!parse_result) {
    LOG(ERROR) << usage;
    return -1;
  }

  std::vector<string> string_flags = {image, graph, labels, input_layer, output_layer, from_node, to_node, root_dir};
  std::vector<int>    int_flags    = {input_width, input_height, input_mean, input_std};

  // We need to call this to set up global state for TensorFlow.
  tensorflow::port::InitMain(argv[0], &argc, &argv);
  if (argc > 1) {
    LOG(ERROR) << "Unknown argument " << argv[1];
    return -1;
  }

  cout << "• Pixel Count:\t\t" << input_width * input_height << endl;
  cout << "• Chanpix Count:\t" << input_width * input_height * numberOfChannels << endl;

  std::vector<Tensor> outputs; // outputs declaration
  std::vector<Tensor> filterTensors;

  string_flags.at(1) = GRAPH_FILE_ORI;
  string_flags.at(5) = "DecodeJpeg/contents";
  string_flags.at(6) = "Mul";
  // ---------------------------------------------------
  outputs = runPartOfGraph(string_flags, int_flags, "tensor0.data", outputs);
  // ---------------------------------------------------

  string_flags.at(1) = GRAPH_FILE_QTR;
  string_flags.at(5) = "Mul";
  string_flags.at(6) = "conv";
  // ---------------------------------------------------
  outputs = runPartOfGraph(string_flags, int_flags, "tensor1.data", outputs);
  // ---------------------------------------------------

        string_flags.at(1) = GRAPH_FILE_ORI;
        string_flags.at(5) = "conv";
        string_flags.at(6) = "conv/conv2d_params";
        // ---------------------------------------------------
        filterTensors = runPartOfGraph(string_flags, int_flags, "filter.data", outputs);
        // ---------------------------------------------------

  // conv -----> conv_1  is processed through a hardware module (CRUCIAL PART!)
  string_flags.at(5) = "conv";
  string_flags.at(6) = "conv_1";
  // ---------------------------------------------------
  outputs = getHardwareResults(string_flags, int_flags, "hardware_out.data", outputs);
  // ---------------------------------------------------

  string_flags.at(1) = GRAPH_FILE_ORI;
  string_flags.at(5) = "conv_1";
  string_flags.at(6) = "softmax";
  // ---------------------------------------------------
  outputs = runPartOfGraph(string_flags, int_flags, "tensor2.data", outputs);
  // ---------------------------------------------------

  // This is for automated testing to make sure we get the expected result with
  // the default settings. We know that label 866 (military uniform) should be
  // the top label for the Admiral Hopper image.
  if (self_test) {
    bool expected_matches;
    Status check_status = CheckTopLabel(outputs, 866, &expected_matches);
    if (!check_status.ok()) {
      LOG(ERROR) << "Running check failed: " << check_status;
      return -1;
    }
    if (!expected_matches) {
      LOG(ERROR) << "Self-test failed!";
      return -1;
    }
  }

  // Do something interesting with the results we've generated.
  Status print_status = PrintTopLabels(outputs, labels);
  if (!print_status.ok()) {
    LOG(ERROR) << "Running print failed: " << print_status;
    return -1;
  }

  return 0;

} // final closing bracket
