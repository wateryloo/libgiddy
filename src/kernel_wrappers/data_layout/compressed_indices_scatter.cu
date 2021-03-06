
#include "kernel_wrappers/common.h"
#ifdef __CUDACC__
#include "kernels/data_layout/compressed_indices_scatter.cuh"
#endif

namespace cuda {
namespace kernels {
namespace scatter {
namespace compressed_indices {

template<unsigned OutputIndexSize, unsigned ElementSize, unsigned InputIndexSize, unsigned RunLengthSize = InputIndexSize>
class kernel_t : public cuda::registered::kernel_t {
public:
	REGISTERED_KERNEL_WRAPPER_BOILERPLATE_DEFINITIONS(kernel_t);

	using element_type      = uint_t<ElementSize>;
	using input_index_type  = uint_t<InputIndexSize>;
	using input_size_type   = size_type_by_index_size<InputIndexSize>;
	using output_index_type = uint_t<OutputIndexSize>;
	using output_size_type  = size_type_by_index_size<OutputIndexSize>;
	using run_length_type   = uint_t<RunLengthSize>;

	launch_configuration_t resolve_launch_configuration(
		device::properties_t           device_properties,
		device_function::attributes_t  kernel_function_attributes,
		size_t                         input_data_length,
		size_t                         anchoring_period,
		launch_configuration_limits_t  limits) const
#ifdef __CUDACC__
	{
		launch_config_resolution_params_t<
			OutputIndexSize, ElementSize, InputIndexSize, RunLengthSize
		> params(
			device_properties,
			input_data_length, anchoring_period);

		return cuda::kernels::resolve_launch_configuration(params, limits);
	}
#else
	;
#endif
};

#ifdef __CUDACC__

template<unsigned OutputIndexSize, unsigned ElementSize, unsigned InputIndexSize, unsigned RunLengthSize>
launch_configuration_t kernel_t<OutputIndexSize, ElementSize, InputIndexSize, RunLengthSize>::resolve_launch_configuration(
	device::properties_t             device_properties,
	device_function::attributes_t    kernel_function_attributes,
	arguments_type                   extra_arguments,
	launch_configuration_limits_t    limits) const
{
	auto input_data_length = any_cast<size_t>(extra_arguments.at("input_data_length"));
	auto anchoring_period  = any_cast<size_t>(extra_arguments.at("anchoring_period"));

	return resolve_launch_configuration(
		device_properties, kernel_function_attributes,
		input_data_length, anchoring_period,
		limits);
}

template<unsigned OutputIndexSize, unsigned ElementSize, unsigned InputIndexSize, unsigned RunLengthSize>
void kernel_t<OutputIndexSize, ElementSize, InputIndexSize, RunLengthSize>::enqueue_launch(
	stream::id_t                      stream,
	const launch_configuration_t&    launch_config,
	arguments_type                   arguments) const
{
	if (launch_config.grid_dimensions == 0) {
		// No patches, so nothing to do
		// TODO: Is this reasonable behavior? Or should we expect not to receive empty grids?
		return;
	}


	auto target                                       = any_cast<element_type*            >(arguments.at("target"                                      ));
	auto data_to_scatter                              = any_cast<const element_type*      >(arguments.at("data_to_scatter"                             ));
	auto scatter_position_run_lengths                 = any_cast<const run_length_type*   >(arguments.at("scatter_position_run_lengths"                ));
	auto scatter_position_run_individual_offset_sizes = any_cast<const unsigned char*     >(arguments.at("scatter_position_run_individual_offset_sizes"));
	auto scatter_position_run_baseline_values         = any_cast<const output_index_type* >(arguments.at("scatter_position_run_baseline_values"        ));
	auto scatter_position_run_offsets_start_pos       = any_cast<const input_index_type*  >(arguments.at("scatter_position_run_offsets_start_pos"      ));
	auto scatter_position_offset_bytes                = any_cast<const unsigned char*     >(arguments.at("scatter_position_offset_bytes"               ));
	auto scatter_position_anchors                     = any_cast<const input_index_type*  >(arguments.at("scatter_position_anchors"                    ));
	// Note: The typing of the next two parameters makes the (trivial)
	// assumption the anchoring period is not the maximum possible length of the input
	auto anchoring_period                             = any_cast<input_index_type         >(arguments.at("anchoring_period"                            ));
	auto num_scatter_position_runs                    = any_cast<input_index_type         >(arguments.at("num_scatter_position_runs"                   ));
	auto input_data_length                            = any_cast<input_size_type          >(arguments.at("input_data_length"                           ));

	cuda::kernel::enqueue_launch(
		*this, stream, launch_config,
		target,
		data_to_scatter,
		scatter_position_run_lengths,
		scatter_position_run_individual_offset_sizes,
		scatter_position_run_baseline_values,
		scatter_position_run_offsets_start_pos,
		scatter_position_offset_bytes,
		scatter_position_anchors,
		anchoring_period,
		num_scatter_position_runs,
		input_data_length
	);
}

template<unsigned OutputIndexSize, unsigned ElementSize, unsigned InputIndexSize, unsigned RunLengthSize>
const cuda::device_function_t kernel_t<OutputIndexSize, ElementSize, InputIndexSize, RunLengthSize>::get_device_function() const
{
	return {
		cuda::kernels::scatter::compressed_indices::scatter
			<OutputIndexSize, ElementSize, InputIndexSize, RunLengthSize>
	};
}


static_block {
	//        OutputIndexSize  ElementSize  InputIndexSize
	//-----------------------------------------------------------------------
	kernel_t< 4,               1,           1 >::registerInSubclassFactory();
	kernel_t< 4,               1,           2 >::registerInSubclassFactory();
	kernel_t< 4,               1,           4 >::registerInSubclassFactory();
	kernel_t< 4,               1,           8 >::registerInSubclassFactory();
	kernel_t< 4,               2,           1 >::registerInSubclassFactory();
	kernel_t< 4,               2,           2 >::registerInSubclassFactory();
	kernel_t< 4,               2,           4 >::registerInSubclassFactory();
	kernel_t< 4,               2,           8 >::registerInSubclassFactory();
	kernel_t< 4,               4,           1 >::registerInSubclassFactory();
	kernel_t< 4,               4,           2 >::registerInSubclassFactory();
	kernel_t< 4,               4,           4 >::registerInSubclassFactory();
	kernel_t< 4,               4,           8 >::registerInSubclassFactory();
	kernel_t< 4,               8,           1 >::registerInSubclassFactory();
	kernel_t< 4,               8,           2 >::registerInSubclassFactory();
	kernel_t< 4,               8,           4 >::registerInSubclassFactory();
	kernel_t< 4,               8,           8 >::registerInSubclassFactory();

	kernel_t< 8,               1,           1 >::registerInSubclassFactory();
	kernel_t< 8,               1,           2 >::registerInSubclassFactory();
	kernel_t< 8,               1,           4 >::registerInSubclassFactory();
	kernel_t< 8,               1,           8 >::registerInSubclassFactory();
	kernel_t< 8,               2,           1 >::registerInSubclassFactory();
	kernel_t< 8,               2,           2 >::registerInSubclassFactory();
	kernel_t< 8,               2,           4 >::registerInSubclassFactory();
	kernel_t< 8,               2,           8 >::registerInSubclassFactory();
	kernel_t< 8,               4,           1 >::registerInSubclassFactory();
	kernel_t< 8,               4,           2 >::registerInSubclassFactory();
	kernel_t< 8,               4,           4 >::registerInSubclassFactory();
	kernel_t< 8,               4,           8 >::registerInSubclassFactory();
	kernel_t< 8,               8,           1 >::registerInSubclassFactory();
	kernel_t< 8,               8,           2 >::registerInSubclassFactory();
	kernel_t< 8,               8,           4 >::registerInSubclassFactory();
	kernel_t< 8,               8,           8 >::registerInSubclassFactory();

}

#endif /* __CUDACC__ */

} // namespace compressed_indices
} // namespace scatter
} // namespace kernels
} // namespace cuda
