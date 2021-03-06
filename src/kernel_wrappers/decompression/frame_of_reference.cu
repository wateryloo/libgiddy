
#include "kernel_wrappers/common.h"
#include "cuda/model_functors.hpp"
#ifdef __CUDACC__
#include "kernels/decompression/frame_of_reference.cuh"
#endif

namespace cuda {
namespace kernels {
namespace decompression {
namespace frame_of_reference {

#ifndef __CUDACC__
// TODO: This is code duplication. The kernel .cuh has the same definition;
// of course, this arbitrary definition is not that great regardless of
// duplication.
enum : serialization_factor_t { DefaultSerializationFactor = 16 };
#endif

// TODO: This currently ignores the possibility of a sorted variant of the kernel

template<
	unsigned IndexSize, typename Uncompressed,
	typename Compressed, typename UnaryModelFunction>
class kernel_t : public cuda::registered::kernel_t {
public:
	REGISTERED_KERNEL_WRAPPER_BOILERPLATE_DEFINITIONS(kernel_t);

	using size_type               = size_type_by_index_size<IndexSize>;
	using model_coefficients_type = typename UnaryModelFunction::coefficients_type;

	launch_configuration_t resolve_launch_configuration(
		device::properties_t           device_properties,
		device_function::attributes_t  kernel_function_attributes,
		size_t                         length,
		size_t                         segment_length,
		launch_configuration_limits_t  limits = { nullopt, nullopt, nullopt} ) const
#ifdef __CUDACC__
	{
		launch_config_resolution_params_t<
			IndexSize, Uncompressed, Compressed, UnaryModelFunction
		> params(
			device_properties,
			length, segment_length);

		return cuda::kernels::resolve_launch_configuration(params, limits);
	}
#else
	;
#endif
};

#ifdef __CUDACC__

template<
	unsigned IndexSize, typename Uncompressed,
	typename Compressed, typename UnaryModelFunction>
launch_configuration_t kernel_t<IndexSize, Uncompressed, Compressed, UnaryModelFunction>::resolve_launch_configuration(
	device::properties_t           device_properties,
	device_function::attributes_t  kernel_function_attributes,
	arguments_type                 extra_arguments,
	launch_configuration_limits_t  limits) const
{
	auto length         = any_cast<size_t>(extra_arguments.at("length"        ));
	auto segment_length = any_cast<size_t>(extra_arguments.at("segment_length"));

	return resolve_launch_configuration(
		device_properties, kernel_function_attributes,
		length, segment_length,
		limits);
}


template<
	unsigned IndexSize, typename Uncompressed,
	typename Compressed,typename UnaryModelFunction>
void kernel_t<IndexSize, Uncompressed, Compressed, UnaryModelFunction>::enqueue_launch(
	stream::id_t                   stream,
	const launch_configuration_t&  launch_config,
	arguments_type                 arguments) const
{
	using index_type = uint_t<IndexSize>;
	using model_coefficients_type = const typename UnaryModelFunction::coefficients_type;

	auto decompressed               = any_cast<Uncompressed*                  >(arguments.at("decompressed"               ));
	auto compressed_input           = any_cast<const Compressed*              >(arguments.at("compressed_input"           ));
	auto segment_model_coefficients = any_cast<const model_coefficients_type* >(arguments.at("segment_model_coefficients" ));
	auto length                     = any_cast<index_type                     >(arguments.at("length"                     ));
	auto segment_length             = any_cast<index_type                     >(arguments.at("segment_length"             ));

	// Note: For every segment, we have a separate model (same family, different coefficients)

	auto num_segments = util::div_rounding_up(length, segment_length);
	auto num_blocks = launch_config.grid_dimensions.x;
	auto segments_per_block = util::div_rounding_up(num_segments, num_blocks);

	cuda::kernel::enqueue_launch(
		*this, stream, launch_config,
		decompressed, compressed_input, segment_model_coefficients,
		length, segment_length, segments_per_block
	);
}

template<
	unsigned IndexSize, typename Uncompressed,
	typename Compressed,typename UnaryModelFunction>
const device_function_t kernel_t<IndexSize, Uncompressed, Compressed, UnaryModelFunction>::get_device_function() const
{
	return reinterpret_cast<const void*>(cuda::kernels::decompression::frame_of_reference::decompress
		<IndexSize, Uncompressed, Compressed, UnaryModelFunction>);
}


static_block {
	namespace functors = cuda::functors;
	namespace unary_models = ::cuda::functors::unary::parametric_model;

	/*
	 * Note: to enable model functions with floating-point coefficients you must make sure
	 * the device-side (and host-side, for the test adapter) floating-point calculations
	 * are consistent. And NB that it's the _consistency_ rather than the _accuracy_ that matters,
	 * because all we need is for the compressor and the decompressor to having the same model-predicted
	 * value, regardless of what it is exactly.
	 *
	 * To do so, read about the IEEE rounding options for floating-point operation result rounding
	 * (nearest even, nearest odd, towards zero, towards infinity, down, up) and, on the device, use the
	 * __fmul_[rn,rz,ru,rd](x,y),   __fadd_[rn,rz,ru,rd](x,y) etc intrinsics
	 */

	//         IndexSize  Uncompressed   Compressed   UnaryModelFunction
	//-------------------------------------------------------------------------------
	kernel_t < 4,         int16_t,       int8_t,      unary_models::linear  < 4, int32_t >  >::registerInSubclassFactory();
	kernel_t < 4,         int32_t,       int8_t,      unary_models::linear  < 4, int32_t >  >::registerInSubclassFactory();
	kernel_t < 4,         int32_t,       int16_t,     unary_models::linear  < 4, int32_t >  >::registerInSubclassFactory();
//	kernel_t < 4,         int16_t,       int8_t,      unary_models::linear  < 4, float   >  >::registerInSubclassFactory();
//	kernel_t < 4,         int32_t,       int8_t,      unary_models::linear  < 4, float   >  >::registerInSubclassFactory();
//	kernel_t < 4,         int32_t,       int16_t,     unary_models::linear  < 4, float   >  >::registerInSubclassFactory();
	kernel_t < 8,         int32_t,       int16_t,     unary_models::linear  < 4, int32_t >  >::registerInSubclassFactory();
	kernel_t < 8,         int32_t,       int16_t,     unary_models::linear  < 8, int32_t >  >::registerInSubclassFactory();
	kernel_t < 4,         int16_t,       int8_t,      unary_models::constant< 4, int32_t >  >::registerInSubclassFactory();
	kernel_t < 4,         int32_t,       int8_t,      unary_models::constant< 4, int32_t >  >::registerInSubclassFactory();
	kernel_t < 4,         int32_t,       int16_t,     unary_models::constant< 4, int32_t >  >::registerInSubclassFactory();
//	kernel_t < 4,         int16_t,       int8_t,      unary_models::constant< 4, float   >  >::registerInSubclassFactory();
//	kernel_t < 4,         int32_t,       int8_t,      unary_models::constant< 4, float   >  >::registerInSubclassFactory();
//	kernel_t < 4,         int32_t,       int16_t,     unary_models::constant< 4, float   >  >::registerInSubclassFactory();
}

#endif /* __CUDACC__ */

} // namespace frame_of_reference
} // namespace decompression
} // namespace kernels
} // namespace cuda
