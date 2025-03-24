#pragma once

#include "Vulkan.hpp"
#include "DeviceMemory.hpp"

namespace Vulkan
{
	class Buffer;
	class CommandPool;
	class Device;

	class Image final
	{
	public:

		Image(const Image&) = delete;
		Image& operator = (const Image&) = delete;
		Image& operator = (Image&&) = delete;
		
		Image(const Device& device, VkExtent2D extent, uint32_t miplevel, VkFormat format);
		Image(const Device& device, VkExtent2D extent, uint32_t miplevel, VkFormat format,VkImageTiling tiling, VkImageUsageFlags usage, bool useForExternal = false);
		Image(Image&& other) noexcept;
		~Image();

		const class Device& Device() const { return device_; }
		VkExtent2D Extent() const { return extent_; }
		VkFormat Format() const { return format_; }

		DeviceMemory AllocateMemory(VkMemoryPropertyFlags properties, bool external = false) const;
		VkMemoryRequirements GetMemoryRequirements() const;

		void TransitionImageLayout(CommandPool& commandPool, VkImageLayout newLayout);
		void CopyFrom(CommandPool& commandPool, const Buffer& buffer);

		void CopyFromToMipLevel(
			Vulkan::CommandPool& commandPool, 
			const Vulkan::Buffer& buffer, 
			uint32_t mipLevel,
			uint32_t mipWidth,
			uint32_t mipHeight);
		
	private:

		const class Device& device_;
		const VkExtent2D extent_;
		const VkFormat format_;
		VkImageLayout imageLayout_;
		uint32_t mipLevel_;
		bool external_;
		VULKAN_HANDLE(VkImage, image_)
	};

}
