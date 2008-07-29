class GDResize
  SUPPORTED_FORMATS = %w(jpg jpeg png gif)

  def resize_image(filename_in, filename_out, box_w, box_h, image_type, jpeg_quality); end

  def resize(filename_in, filename_out, size, options={})
    options.merge!({
      :cropped => false,
      :jpeg_quality => -1
    })

    ext = filename_in.match(/\.(\w+)$/).to_a.last.downcase
    raise "#{ext} extension not recognised. We only support #{SUPPORTED_FORMATS.join(", ")}" unless SUPPORTED_FORMATS.include?(ext)
    resize_image(filename_in, filename_out, size[0], size[1], SUPPORTED_FORMATS.index(ext), options[:jpeg_quality])
  end

  inline do |builder|
    builder.include '"gd.h"'
    builder.add_link_flags "-lgd"

    builder.c <<-"END"
      void resize_image(char *filename_in, char *filename_out, int box_w, int box_h, int image_type, int jpeg_quality) {
        gdImagePtr im_in;
        gdImagePtr im_out;
        int x, y;
        float r;
        FILE *in;
        FILE *out;

        /* Load original file */
        in = fopen(filename_in, "rb");

        /* Support diff image types: jpg jpeg png gif */
        switch(image_type) {
          case 0:
          case 1: im_in = gdImageCreateFromJpeg(in);
                  break;
          case 2: im_in = gdImageCreateFromPng(in);
                  break;
          case 3: im_in = gdImageCreateFromGif(in);
                  break;
          default: puts("Image type not recognised");
        }

        fclose(in);

        /* Only resize if the image is out of bounds - this should be done outside of C */
        /*if(im_in->sx > box_w || im_in->sy > box_h) {
          if(im_in->sx > im_in->sy) {
            r = (float)im_in->sy / (float)im_in->sx;
            x = box_w;
            y = floor(box_h * r);
          } else {
            r = (float)im_in->sx / (float)im_in->sy;
            x = floor(box_w * r);
            y = box_h;
          }
        } else {
          x = im_in->sx;
          y = im_in->sy;
        }*/
        
        /* Just resize to the dimensions we are given for now */
        x = box_w;
        y = box_h;

        /* Make the output image four times as small on both axes. Use
          a true color image so that we can interpolate colors. */
        im_out = gdImageCreateTrueColor(x,y);
        /* Now copy the large image, but four times smaller */
        gdImageCopyResampled(im_out, im_in, 0, 0, 0, 0,
          im_out->sx, im_out->sy,
          im_in->sx, im_in->sy);
        out = fopen(filename_out, "wb");

        /* TODO: support diff image types */
        /* Support diff image types: jpg jpeg png gif */
        switch(image_type) {
          case 0:
          case 1: gdImageJpeg(im_out, out, 80);
                  break;
          case 2: gdImagePng(im_out, out);
                  break;
          case 3: gdImageGif(im_out, out);
                  break;
          default: puts("Image type not recognised");
        }

        fclose(out);
        gdImageDestroy(im_in);
        gdImageDestroy(im_out);
      }
    END
  end
end